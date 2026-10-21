using Microsoft.Extensions.Logging.Abstractions;
using Mnp.Application.Abstractions;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Application.Tests;

public sealed class PortingRequestServiceTests
{
    private const string Msisdn = "+306900000001";
    private const string DonorNetworkCode = "ATT";
    private const string RecipientNetworkCode = "VZW";
    private static readonly DateOnly RequestedPortingDate = new(2026, 11, 1);
    private const string PacCode = "ABC123";
    private static readonly DateOnly PacIssuedDate = new(2026, 10, 1);

    private static PortingRequest MakeRequest(PortingStatus status) => new()
    {
        Id = 1,
        Msisdn = Msisdn,
        DonorNetworkCode = DonorNetworkCode,
        RecipientNetworkCode = RecipientNetworkCode,
        Status = status,
        RequestedPortingDate = RequestedPortingDate,
        PacCode = PacCode,
        PacIssuedDate = PacIssuedDate
    };

    [Fact]
    public async Task SubmitAsync_HappyPath_CreatesThenValidatesThenRaisesValidationPassed()
    {
        var repository = new FakePortingRequestRepository(MakeRequest(PortingStatus.Approved));
        var carrierClient = new FakeCarrierNetworkClient { Result = new DonorValidationResult(true, null) };
        var service = new PortingRequestService(repository, carrierClient, NullLogger<PortingRequestService>.Instance);

        var result = await service.SubmitAsync(
            Msisdn, DonorNetworkCode, RecipientNetworkCode, RequestedPortingDate, PacCode, PacIssuedDate,
            CancellationToken.None);

        Assert.Equal(PortingStatus.Approved, result.Status);
        Assert.Equal(["CreateAsync", "RaiseEventAsync", "GetByIdAsync"], repository.CallOrder);

        Assert.Single(repository.CreateCalls);
        Assert.True(carrierClient.WasCalled);
        var (eventType, context) = Assert.Single(repository.RaiseEventCalls);
        Assert.Equal("VALIDATION_PASSED", eventType);
        Assert.Null(context);

        Assert.True(repository.CreateCompletedBeforeValidate);
        Assert.True(carrierClient.ValidateCompletedBeforeRaiseEvent);
    }

    [Fact]
    public async Task SubmitAsync_DonorValidationFails_RaisesValidationFailedWithDenialReason()
    {
        var repository = new FakePortingRequestRepository(MakeRequest(PortingStatus.Rejected));
        var carrierClient = new FakeCarrierNetworkClient
        {
            Result = new DonorValidationResult(false, "subscriber not found")
        };
        var service = new PortingRequestService(repository, carrierClient, NullLogger<PortingRequestService>.Instance);

        var result = await service.SubmitAsync(
            Msisdn, DonorNetworkCode, RecipientNetworkCode, RequestedPortingDate, PacCode, PacIssuedDate,
            CancellationToken.None);

        Assert.Equal(PortingStatus.Rejected, result.Status);
        var (eventType, context) = Assert.Single(repository.RaiseEventCalls);
        Assert.Equal("VALIDATION_FAILED", eventType);
        Assert.Equal("subscriber not found", context);
    }

    [Fact]
    public async Task SubmitAsync_WhenDonorValidationThrows_RequestWasAlreadyCreatedAndEventIsNeverRaised()
    {
        var repository = new FakePortingRequestRepository(MakeRequest(PortingStatus.Validating));
        var carrierClient = new FakeCarrierNetworkClient { ThrowOnValidate = new HttpRequestException("donor network unreachable") };
        var service = new PortingRequestService(repository, carrierClient, NullLogger<PortingRequestService>.Instance);

        await Assert.ThrowsAsync<HttpRequestException>(() => service.SubmitAsync(
            Msisdn, DonorNetworkCode, RecipientNetworkCode, RequestedPortingDate, PacCode, PacIssuedDate,
            CancellationToken.None));

        Assert.Single(repository.CreateCalls);
        Assert.Empty(repository.RaiseEventCalls);
    }

    private sealed class FakePortingRequestRepository(PortingRequest requestToReturn) : IPortingRequestRepository
    {
        public List<(string Msisdn, string DonorNetworkCode, string RecipientNetworkCode, DateOnly RequestedPortingDate, string PacCode, DateOnly PacIssuedDate)> CreateCalls { get; } = [];
        public List<(string EventType, string? Context)> RaiseEventCalls { get; } = [];
        public List<string> CallOrder { get; } = [];
        public bool CreateCompletedBeforeValidate { get; private set; }

        public Task<long> CreateAsync(
            string msisdn,
            string donorNetworkCode,
            string recipientNetworkCode,
            DateOnly requestedPortingDate,
            string pacCode,
            DateOnly pacIssuedDate,
            CancellationToken cancellationToken)
        {
            CreateCalls.Add((msisdn, donorNetworkCode, recipientNetworkCode, requestedPortingDate, pacCode, pacIssuedDate));
            CallOrder.Add("CreateAsync");
            CreateCompletedBeforeValidate = true;
            return Task.FromResult(1L);
        }

        public Task<PortingRequest?> GetByIdAsync(long id, CancellationToken cancellationToken)
        {
            CallOrder.Add("GetByIdAsync");
            return Task.FromResult<PortingRequest?>(requestToReturn);
        }

        public Task<IReadOnlyList<PortingRequest>> GetByMsisdnAsync(string msisdn, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task RaiseEventAsync(long id, string eventType, string? context, CancellationToken cancellationToken)
        {
            RaiseEventCalls.Add((eventType, context));
            CallOrder.Add("RaiseEventAsync");
            return Task.CompletedTask;
        }
    }

    private sealed class FakeCarrierNetworkClient : ICarrierNetworkClient
    {
        public DonorValidationResult? Result { get; init; }
        public Exception? ThrowOnValidate { get; init; }
        public bool WasCalled { get; private set; }
        public bool ValidateCompletedBeforeRaiseEvent { get; private set; }

        public Task<DonorValidationResult> ValidateSubscriberAsync(
            string msisdn, string donorNetworkCode, CancellationToken cancellationToken)
        {
            WasCalled = true;
            if (ThrowOnValidate is not null)
            {
                throw ThrowOnValidate;
            }

            ValidateCompletedBeforeRaiseEvent = true;
            return Task.FromResult(Result!);
        }

        public Task<DonorValidationResultV2> ValidateSubscriberV2Async(
            SubscriberValidationRequestV2 request, CancellationToken cancellationToken) =>
            throw new NotSupportedException();
    }
}
