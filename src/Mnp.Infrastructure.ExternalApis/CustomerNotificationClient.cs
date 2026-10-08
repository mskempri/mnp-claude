using System.Net.Http.Json;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

/// <summary>
/// Notifies the subscriber (e.g. an SMS/email/push gateway) of a porting-request event.
/// Registered with a resilience handler (retry/circuit-breaker/timeout) in Program.cs.
/// </summary>
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
