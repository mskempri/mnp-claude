namespace Mnp.Application.Abstractions;

public interface ICarrierNetworkClient
{
    Task<DonorValidationResult> ValidateSubscriberAsync(
        string msisdn,
        string donorNetworkCode,
        CancellationToken cancellationToken);

    Task<DonorValidationResultV2> ValidateSubscriberV2Async(
        SubscriberValidationRequestV2 request,
        CancellationToken cancellationToken);
}

public sealed record DonorValidationResult(bool IsEligible, string? DenialReason);

public sealed record SubscriberValidationRequestV2(
    string Msisdn,
    string DonorNetworkCode,
    string RecipientNetworkCode);

public sealed record DonorValidationResultV2(
    string Status,
    string? DenialReason,
    DateTimeOffset? EligibleUntil);
