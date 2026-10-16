using Microsoft.Extensions.Logging.Abstractions;
using Mnp.Application.Abstractions;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Application.Tests;

public sealed class OutboxRelayServiceTests
{
    private static OutboxEvent MakeEvent(NotificationAudience audience) => new()
    {
        Id = 1,
        RequestId = 100,
        EventType = "REQUEST_APPROVED",
        Audience = audience,
        Msisdn = "+306900000000",
        DonorNetworkCode = "ATT",
        RecipientNetworkCode = "VZW"
    };

    private static OutboxRelayService CreateService(
        FakeOutboxRepository repository,
        FakeCarrierNetworkNotificationClient carrierClient,
        FakeCustomerNotificationClient customerClient) =>
        new(repository, carrierClient, customerClient, NullLogger<OutboxRelayService>.Instance);

    [Fact]
    public async Task ProcessNextAsync_ReturnsFalse_WhenNothingToClaim()
    {
        var repository = new FakeOutboxRepository(null);
        var service = CreateService(repository, new FakeCarrierNetworkNotificationClient(), new FakeCustomerNotificationClient());

        var result = await service.ProcessNextAsync(CancellationToken.None);

        Assert.False(result);
    }

    [Fact]
    public async Task ProcessNextAsync_DonorNetworkAudience_NotifiesDonorAndMarksPublished()
    {
        var repository = new FakeOutboxRepository(MakeEvent(NotificationAudience.DonorNetwork));
        var carrierClient = new FakeCarrierNetworkNotificationClient();
        var service = CreateService(repository, carrierClient, new FakeCustomerNotificationClient());

        var result = await service.ProcessNextAsync(CancellationToken.None);

        Assert.True(result);
        Assert.Equal(("ATT", "REQUEST_APPROVED", "+306900000000"), Assert.Single(carrierClient.Calls));
        Assert.Equal(1, repository.PublishedIds.Single());
        Assert.Empty(repository.FailedCalls);
    }

    [Fact]
    public async Task ProcessNextAsync_RecipientNetworkAudience_NotifiesRecipientAndMarksPublished()
    {
        var repository = new FakeOutboxRepository(MakeEvent(NotificationAudience.RecipientNetwork));
        var carrierClient = new FakeCarrierNetworkNotificationClient();
        var service = CreateService(repository, carrierClient, new FakeCustomerNotificationClient());

        await service.ProcessNextAsync(CancellationToken.None);

        Assert.Equal(("VZW", "REQUEST_APPROVED", "+306900000000"), Assert.Single(carrierClient.Calls));
        Assert.Equal(1, repository.PublishedIds.Single());
    }

    [Fact]
    public async Task ProcessNextAsync_CustomerAudience_NotifiesCustomerAndMarksPublished()
    {
        var repository = new FakeOutboxRepository(MakeEvent(NotificationAudience.Customer));
        var customerClient = new FakeCustomerNotificationClient();
        var service = CreateService(repository, new FakeCarrierNetworkNotificationClient(), customerClient);

        await service.ProcessNextAsync(CancellationToken.None);

        Assert.Equal(("+306900000000", "REQUEST_APPROVED"), Assert.Single(customerClient.Calls));
        Assert.Equal(1, repository.PublishedIds.Single());
    }

    [Fact]
    public async Task ProcessNextAsync_OperationsAudience_CallsNoClientButStillMarksPublished()
    {
        var repository = new FakeOutboxRepository(MakeEvent(NotificationAudience.Operations));
        var carrierClient = new FakeCarrierNetworkNotificationClient();
        var customerClient = new FakeCustomerNotificationClient();
        var service = CreateService(repository, carrierClient, customerClient);

        await service.ProcessNextAsync(CancellationToken.None);

        Assert.Empty(carrierClient.Calls);
        Assert.Empty(customerClient.Calls);
        Assert.Equal(1, repository.PublishedIds.Single());
    }

    [Fact]
    public async Task ProcessNextAsync_WhenDispatchThrows_MarksFailedInsteadOfPublished()
    {
        var repository = new FakeOutboxRepository(MakeEvent(NotificationAudience.Customer));
        var customerClient = new FakeCustomerNotificationClient { ThrowOnNotify = new InvalidOperationException("gateway unreachable") };
        var service = CreateService(repository, new FakeCarrierNetworkNotificationClient(), customerClient);

        await service.ProcessNextAsync(CancellationToken.None);

        Assert.Empty(repository.PublishedIds);
        var (id, error) = Assert.Single(repository.FailedCalls);
        Assert.Equal(1, id);
        Assert.Equal("gateway unreachable", error);
    }

    private sealed class FakeOutboxRepository(OutboxEvent? eventToReturn) : IOutboxRepository
    {
        private bool _claimed;
        public List<long> PublishedIds { get; } = [];
        public List<(long Id, string Error)> FailedCalls { get; } = [];

        public Task<OutboxEvent?> ClaimNextPendingEventAsync(CancellationToken cancellationToken)
        {
            if (_claimed || eventToReturn is null)
            {
                return Task.FromResult<OutboxEvent?>(null);
            }

            _claimed = true;
            return Task.FromResult<OutboxEvent?>(eventToReturn);
        }

        public Task MarkPublishedAsync(long outboxId, CancellationToken cancellationToken)
        {
            PublishedIds.Add(outboxId);
            return Task.CompletedTask;
        }

        public Task MarkFailedAsync(long outboxId, string error, CancellationToken cancellationToken)
        {
            FailedCalls.Add((outboxId, error));
            return Task.CompletedTask;
        }

        public Task<IReadOnlyList<OutboxEventSummary>> GetRecentAsync(int limit, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<OutboxEventSummary>>([]);
    }

    private sealed class FakeCarrierNetworkNotificationClient : ICarrierNetworkNotificationClient
    {
        public List<(string NetworkCode, string EventType, string Msisdn)> Calls { get; } = [];

        public Task NotifyAsync(string networkCode, string eventType, string msisdn, CancellationToken cancellationToken)
        {
            Calls.Add((networkCode, eventType, msisdn));
            return Task.CompletedTask;
        }
    }

    private sealed class FakeCustomerNotificationClient : ICustomerNotificationClient
    {
        public List<(string Msisdn, string EventType)> Calls { get; } = [];
        public Exception? ThrowOnNotify { get; init; }

        public Task NotifyAsync(string msisdn, string eventType, CancellationToken cancellationToken)
        {
            if (ThrowOnNotify is not null)
            {
                throw ThrowOnNotify;
            }

            Calls.Add((msisdn, eventType));
            return Task.CompletedTask;
        }
    }
}
