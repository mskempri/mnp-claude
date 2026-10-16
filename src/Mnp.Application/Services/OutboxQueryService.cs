using Mnp.Application.Abstractions;
using Mnp.Domain;

namespace Mnp.Application.Services;

public sealed class OutboxQueryService(IOutboxRepository repository)
{
    public Task<IReadOnlyList<OutboxEventSummary>> GetRecentAsync(int limit, CancellationToken cancellationToken) =>
        repository.GetRecentAsync(limit, cancellationToken);
}
