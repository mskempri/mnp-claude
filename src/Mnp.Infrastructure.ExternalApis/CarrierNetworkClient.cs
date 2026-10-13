using System.Net.Http.Json;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

public sealed class CarrierNetworkClient(HttpClient httpClient) : ICarrierNetworkClient
{
    public async Task<DonorValidationResult> ValidateSubscriberAsync(
        string msisdn,
        string donorNetworkCode,
        CancellationToken cancellationToken)
    {
        var response = await httpClient.PostAsJsonAsync(
            $"networks/{donorNetworkCode}/subscribers/validate",
            new { msisdn },
            cancellationToken);

        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<SubscriberValidationResponse>(cancellationToken)
            ?? throw new InvalidOperationException("Donor network returned an empty validation response.");

        return new DonorValidationResult(result.IsEligible, result.DenialReason);
    }

    private sealed record SubscriberValidationResponse(bool IsEligible, string? DenialReason);
}
