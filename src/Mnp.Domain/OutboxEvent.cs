namespace Mnp.Domain;

/// <summary>
/// A claimed notification to dispatch. Fields are already shaped from the
/// outbox row's JSON payload by the time this reaches Application/Worker code
/// — see <c>Mnp.Infrastructure.Database.OutboxRepository</c>.
/// </summary>
public sealed class OutboxEvent
{
    public required long Id { get; init; }
    public required long RequestId { get; init; }
    public required string EventType { get; init; }
    public required NotificationAudience Audience { get; init; }
    public required string Msisdn { get; init; }
    public required string DonorNetworkCode { get; init; }
    public required string RecipientNetworkCode { get; init; }
}
