namespace Mnp.Application.Abstractions;

/// <summary>
/// Outbound calls to external carrier-network / central MNP registry APIs.
/// </summary>
public interface ICarrierNetworkClient
{
    Task<DonorValidationResult> ValidateSubscriberAsync(
        string msisdn,
        string donorNetworkCode,
        CancellationToken cancellationToken);
}

public sealed record DonorValidationResult(bool IsEligible, string? DenialReason);
