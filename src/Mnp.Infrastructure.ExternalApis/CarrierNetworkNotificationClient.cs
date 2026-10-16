using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

/// <summary>
/// Notifies a carrier network (donor or recipient) of a porting-request event.
/// Registered with a resilience handler (retry/circuit-breaker/timeout) in Program.cs.
/// </summary>
public sealed class CarrierNetworkNotificationClient(HttpClient httpClient, ILogger<CarrierNetworkNotificationClient> logger)
    : ICarrierNetworkNotificationClient
{
    public async Task NotifyAsync(
        string networkCode,
        string eventType,
        string msisdn,
        CancellationToken cancellationToken)
    {
        logger.LogInformation("Notifying network {NetworkCode} of event {EventType}", networkCode, eventType);

        try
        {
            var response = await httpClient.PostAsJsonAsync(
                $"networks/{networkCode}/notifications",
                new { eventType, msisdn },
                cancellationToken);
            response.EnsureSuccessStatusCode();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to notify network {NetworkCode} of event {EventType}", networkCode, eventType);
            throw;
        }
    }
}
