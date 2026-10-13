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
        string pacCode,
        DateOnly pacIssuedDate,
        CancellationToken cancellationToken)
    {
        // fn_create_request raises CREATED internally, which moves the
        // request straight to VALIDATING - it exists and its SLA timer is
        // already running before the donor-network call below ever happens,
        // so a failure/crash mid-call leaves a visible VALIDATING row (whose
        // timer will eventually flag SLA_AT_RISK) instead of silently
        // losing the submission.
        var id = await repository.CreateAsync(
            msisdn, donorNetworkCode, recipientNetworkCode, requestedPortingDate,
            pacCode, pacIssuedDate, cancellationToken);

        var validation = await carrierNetworkClient.ValidateSubscriberAsync(
            msisdn, donorNetworkCode, cancellationToken);

        // The resulting status (APPROVED or REJECTED) is decided entirely by
        // the database's rule engine, not chosen here.
        await repository.RaiseEventAsync(
            id,
            validation.IsEligible ? "VALIDATION_PASSED" : "VALIDATION_FAILED",
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

        var updated = await repository.GetByIdAsync(id, cancellationToken);
        return updated ?? throw new InvalidOperationException(
            $"Porting request {id} was updated but could not be re-read.");
    }
}
