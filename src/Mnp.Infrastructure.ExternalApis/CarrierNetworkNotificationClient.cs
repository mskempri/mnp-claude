using System.Net.Http.Json;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

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
