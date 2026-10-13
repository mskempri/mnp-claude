namespace Mnp.Application.Abstractions;

public interface ICarrierNetworkClient
{
    Task<DonorValidationResult> ValidateSubscriberAsync(
        string msisdn,
        string donorNetworkCode,
        CancellationToken cancellationToken);
}

public sealed record DonorValidationResult(bool IsEligible, string? DenialReason);
