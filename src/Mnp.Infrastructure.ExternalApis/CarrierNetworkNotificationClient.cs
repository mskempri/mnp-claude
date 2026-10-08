using System.Net.Http.Json;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

/// <summary>
/// Notifies a carrier network (donor or recipient) of a porting-request event.
/// Registered with a resilience handler (retry/circuit-breaker/timeout) in Program.cs.
/// </summary>
public sealed class CarrierNetworkNotificationClient(HttpClient httpClient) : ICarrierNetworkNotificationClient
{
    public async Task NotifyAsync(
        string networkCode,
        string eventType,
        string msisdn,
        CancellationToken cancellationToken)
    {
        var response = await httpClient.PostAsJsonAsync(
            $"networks/{networkCode}/notifications",
            new { eventType, msisdn },
            cancellationToken);

        response.EnsureSuccessStatusCode();
    }
}
