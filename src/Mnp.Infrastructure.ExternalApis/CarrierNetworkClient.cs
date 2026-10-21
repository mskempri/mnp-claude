using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

/// <summary>
/// Calls the donor network's subscriber-validation API as part of the porting workflow.
/// Registered with a resilience handler (retry/circuit-breaker/timeout) in Program.cs.
/// </summary>
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

    public async Task<DonorValidationResultV2> ValidateSubscriberV2Async(
        SubscriberValidationRequestV2 request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Calling donor network {NetworkCode} to validate subscriber (v2)", request.DonorNetworkCode);

        HttpResponseMessage response;
        try
        {
            response = await httpClient.PostAsJsonAsync(
                $"networks/{request.DonorNetworkCode}/subscribers/validate/v2",
                request,
                cancellationToken);
            response.EnsureSuccessStatusCode();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Donor network {NetworkCode} validation call (v2) failed", request.DonorNetworkCode);
            throw;
        }

        var result = await response.Content.ReadFromJsonAsync<SubscriberValidationResponseV2>(cancellationToken)
            ?? throw new InvalidOperationException("Donor network returned an empty validation response.");

        logger.LogInformation(
            "Donor network {NetworkCode} validation result (v2): status={Status}",
            request.DonorNetworkCode, result.Status);

        return new DonorValidationResultV2(result.Status, result.DenialReason, result.EligibleUntil);
    }

    private sealed record SubscriberValidationResponse(bool IsEligible, string? DenialReason);

    private sealed record SubscriberValidationResponseV2(string Status, string? DenialReason, DateTimeOffset? EligibleUntil);
}
