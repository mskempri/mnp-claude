using Mnp.Domain;

namespace Mnp.Application.Abstractions;

/// <summary>
/// Gateway to the PL/SQL package that owns porting-request logic (PKG_PORTING_REQUESTS).
/// Implementations call stored functions/procedures; they must not contain business rules themselves.
/// </summary>
public interface IPortingRequestRepository
{
    Task<long> CreateAsync(
        string msisdn,
        string donorNetworkCode,
        string recipientNetworkCode,
        DateOnly requestedPortingDate,
        string pacCode,
        DateOnly pacIssuedDate,
        CancellationToken cancellationToken);

    Task<PortingRequest?> GetByIdAsync(long id, CancellationToken cancellationToken);

    Task<IReadOnlyList<PortingRequest>> GetByMsisdnAsync(string msisdn, CancellationToken cancellationToken);

    /// <summary>
    /// Raises an event against the request's current status. The database's
    /// rule engine (PKG_WORKFLOW_ENGINE) alone decides the resulting status -
    /// there is no way to set status directly, only to raise events and read
    /// back what happened.
    /// </summary>
    Task RaiseEventAsync(
        long id,
        string eventType,
        string? context,
        CancellationToken cancellationToken);
}
