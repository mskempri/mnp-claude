using System.Net.Http.Json;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

public sealed class CustomerNotificationClient(HttpClient httpClient) : ICustomerNotificationClient
{
    public async Task NotifyAsync(
        string msisdn,
        string eventType,
        CancellationToken cancellationToken)
    {
        var response = await httpClient.PostAsJsonAsync(
            $"customers/{msisdn}/notifications",
            new { eventType },
            cancellationToken);

        response.EnsureSuccessStatusCode();
    }
}
