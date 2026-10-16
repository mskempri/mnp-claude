using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;
using Mnp.Domain;

namespace Mnp.Application.Services;

public sealed class PortingRequestService(
    IPortingRequestRepository repository,
    ICarrierNetworkClient carrierNetworkClient,
    ILogger<PortingRequestService> logger)
{
    public async Task<PortingRequest> SubmitAsync(
        string msisdn,
        string donorNetworkCode,
        string recipientNetworkCode,
        DateOnly requestedPortingDate,
        string pacCode,
        DateOnly pacIssuedDate,
        CancellationToken cancellationToken)
    {
        var id = await repository.CreateAsync(
            msisdn, donorNetworkCode, recipientNetworkCode, requestedPortingDate,
            pacCode, pacIssuedDate, cancellationToken);
        logger.LogInformation("Porting request {RequestId} created, pending donor-network validation", id);

        var validation = await carrierNetworkClient.ValidateSubscriberAsync(
            msisdn, donorNetworkCode, cancellationToken);

        var eventType = validation.IsEligible ? "VALIDATION_PASSED" : "VALIDATION_FAILED";
        if (validation.IsEligible)
        {
            logger.LogInformation("Porting request {RequestId} validation result: {EventType}", id, eventType);
        }
        else
        {
            logger.LogWarning("Porting request {RequestId} rejected by donor network", id);
        }

        await repository.RaiseEventAsync(
            id,
            eventType,
            validation.IsEligible ? null : validation.DenialReason,
            cancellationToken);

        var created = await repository.GetByIdAsync(id, cancellationToken);
        return created ?? throw new InvalidOperationException(
            $"Porting request {id} was created but could not be re-read.");
    }

    public Task<PortingRequest?> GetAsync(long id, CancellationToken cancellationToken) =>
        repository.GetByIdAsync(id, cancellationToken);

    public Task<IReadOnlyList<PortingRequest>> GetByMsisdnAsync(string msisdn, CancellationToken cancellationToken) =>
        repository.GetByMsisdnAsync(msisdn, cancellationToken);

    public async Task<PortingRequest> RaiseEventAsync(
        long id, string eventType, string? context, CancellationToken cancellationToken)
    {
        await repository.RaiseEventAsync(id, eventType, context, cancellationToken);
        logger.LogInformation("Porting request {RequestId} event {EventType} applied", id, eventType);

        var updated = await repository.GetByIdAsync(id, cancellationToken);
        return updated ?? throw new InvalidOperationException(
            $"Porting request {id} was updated but could not be re-read.");
    }
}
