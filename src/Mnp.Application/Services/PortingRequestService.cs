using Mnp.Application.Abstractions;
using Mnp.Domain;

namespace Mnp.Application.Services;

/// <summary>
/// Thin orchestration: validate with the donor network over HTTP, then hand off
/// to the database package, which owns the actual business rules and state machine.
/// </summary>
public sealed class PortingRequestService(
    IPortingRequestRepository repository,
    ICarrierNetworkClient carrierNetworkClient)
{
    public async Task<PortingRequest> SubmitAsync(
        string msisdn,
        string donorNetworkCode,
        string recipientNetworkCode,
        DateOnly requestedPortingDate,
        CancellationToken cancellationToken)
    {
        var validation = await carrierNetworkClient.ValidateSubscriberAsync(
            msisdn, donorNetworkCode, cancellationToken);

        var id = await repository.CreateAsync(
            msisdn, donorNetworkCode, recipientNetworkCode, requestedPortingDate, cancellationToken);

        if (!validation.IsEligible)
        {
            await repository.UpdateStatusAsync(
                id, PortingStatus.Rejected, validation.DenialReason, cancellationToken);
        }

        var created = await repository.GetByIdAsync(id, cancellationToken);
        return created ?? throw new InvalidOperationException(
            $"Porting request {id} was created but could not be re-read.");
    }

    public Task<PortingRequest?> GetAsync(long id, CancellationToken cancellationToken) =>
        repository.GetByIdAsync(id, cancellationToken);

    public Task<IReadOnlyList<PortingRequest>> GetByMsisdnAsync(string msisdn, CancellationToken cancellationToken) =>
        repository.GetByMsisdnAsync(msisdn, cancellationToken);
}
