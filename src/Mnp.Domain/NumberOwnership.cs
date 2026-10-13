namespace Mnp.Domain;

public sealed class NumberOwnership
{
    public required string Msisdn { get; init; }
    public required string CurrentNetworkCode { get; init; }
    public DateTimeOffset LastPortedAt { get; init; }
    public long? LastPortingRequestId { get; init; }
}
