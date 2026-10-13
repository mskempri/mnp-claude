namespace Mnp.Domain;

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
