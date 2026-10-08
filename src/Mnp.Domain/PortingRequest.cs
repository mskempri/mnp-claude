namespace Mnp.Domain;

public sealed class PortingRequest
{
    public long Id { get; init; }
    public required string Msisdn { get; init; }
    public required string DonorNetworkCode { get; init; }
    public required string RecipientNetworkCode { get; init; }
    public PortingStatus Status { get; init; }
    public DateOnly RequestedPortingDate { get; init; }
    public string? RejectionReason { get; init; }
    public DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset UpdatedAt { get; init; }
}
