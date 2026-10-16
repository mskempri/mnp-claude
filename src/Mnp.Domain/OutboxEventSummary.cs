namespace Mnp.Domain;

/// <summary>
/// Read-only view of an outbox row for observability (e.g. a status
/// dashboard) — distinct from <see cref="OutboxEvent"/>, which is the shape
/// Mnp.Worker claims and dispatches. Audience is nullable because rows
/// enqueued before that column existed (Phase A dev data) predate it.
/// </summary>
public sealed class OutboxEventSummary
{
    public required long Id { get; init; }
    public required long RequestId { get; init; }
    public required string EventType { get; init; }
    public required NotificationAudience? Audience { get; init; }
    public required OutboxEventStatus Status { get; init; }
    public required int AttemptCount { get; init; }
    public string? LastError { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset? ClaimedAt { get; init; }
    public DateTimeOffset? PublishedAt { get; init; }
}
