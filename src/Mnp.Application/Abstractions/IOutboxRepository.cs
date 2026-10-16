using Mnp.Domain;

namespace Mnp.Application.Abstractions;

/// <summary>
/// Gateway to PKG_OUTBOX. Claiming, publishing, and failing are each their
/// own call — there is no single transaction spanning a claim and its
/// eventual mark, since a notification dispatch (an HTTP call) happens in
/// between. See PKG_OUTBOX's header comment for the accepted
/// orphaned-claim-on-crash limitation this implies.
/// </summary>
public interface IOutboxRepository
{
    Task<OutboxEvent?> ClaimNextPendingEventAsync(CancellationToken cancellationToken);

    Task MarkPublishedAsync(long outboxId, CancellationToken cancellationToken);

    Task MarkFailedAsync(long outboxId, string error, CancellationToken cancellationToken);

    Task<IReadOnlyList<OutboxEventSummary>> GetRecentAsync(int limit, CancellationToken cancellationToken);
}
