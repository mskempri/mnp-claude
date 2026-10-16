using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

public sealed class CarrierNetworkClient(HttpClient httpClient, ILogger<CarrierNetworkClient> logger) : ICarrierNetworkClient
{
    public async Task<DonorValidationResult> ValidateSubscriberAsync(
        string msisdn,
        string donorNetworkCode,
        CancellationToken cancellationToken)
    {
        logger.LogInformation("Calling donor network {NetworkCode} to validate subscriber", donorNetworkCode);

        HttpResponseMessage response;
        try
        {
            response = await httpClient.PostAsJsonAsync(
                $"networks/{donorNetworkCode}/subscribers/validate",
                new { msisdn },
                cancellationToken);
            response.EnsureSuccessStatusCode();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Donor network {NetworkCode} validation call failed", donorNetworkCode);
            throw;
        }

        var result = await response.Content.ReadFromJsonAsync<SubscriberValidationResponse>(cancellationToken)
            ?? throw new InvalidOperationException("Donor network returned an empty validation response.");

        logger.LogInformation(
            "Donor network {NetworkCode} validation result: eligible={IsEligible}", donorNetworkCode, result.IsEligible);

        return new DonorValidationResult(result.IsEligible, result.DenialReason);
    }

    private sealed record SubscriberValidationResponse(bool IsEligible, string? DenialReason);
}
