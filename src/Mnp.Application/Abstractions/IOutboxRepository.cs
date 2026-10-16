using Mnp.Domain;

namespace Mnp.Application.Abstractions;

public interface IOutboxRepository
{
    Task<OutboxEvent?> ClaimNextPendingEventAsync(CancellationToken cancellationToken);

    Task MarkPublishedAsync(long outboxId, CancellationToken cancellationToken);

    Task MarkFailedAsync(long outboxId, string error, CancellationToken cancellationToken);

    Task<IReadOnlyList<OutboxEventSummary>> GetRecentAsync(int limit, CancellationToken cancellationToken);
}
