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
        CancellationToken cancellationToken);

    Task<PortingRequest?> GetByIdAsync(long id, CancellationToken cancellationToken);

    Task<IReadOnlyList<PortingRequest>> GetByMsisdnAsync(string msisdn, CancellationToken cancellationToken);

    Task UpdateStatusAsync(
        long id,
        PortingStatus status,
        string? reason,
        CancellationToken cancellationToken);
}
