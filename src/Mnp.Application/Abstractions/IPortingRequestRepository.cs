using Mnp.Domain;

namespace Mnp.Application.Abstractions;

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

    Task RaiseEventAsync(
        long id,
        string eventType,
        string? context,
        CancellationToken cancellationToken);
}
