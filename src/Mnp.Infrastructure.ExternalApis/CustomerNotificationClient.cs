using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;

namespace Mnp.Infrastructure.ExternalApis;

/// <summary>
/// Notifies the subscriber (e.g. an SMS/email/push gateway) of a porting-request event.
/// Registered with a resilience handler (retry/circuit-breaker/timeout) in Program.cs.
/// </summary>
public sealed class CustomerNotificationClient(HttpClient httpClient, ILogger<CustomerNotificationClient> logger)
    : ICustomerNotificationClient
{
    public async Task NotifyAsync(
        string msisdn,
        string eventType,
        CancellationToken cancellationToken)
    {
        logger.LogInformation("Notifying customer of event {EventType}", eventType);

        try
        {
            var response = await httpClient.PostAsJsonAsync(
                $"customers/{msisdn}/notifications",
                new { eventType },
                cancellationToken);
            response.EnsureSuccessStatusCode();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to notify customer of event {EventType}", eventType);
            throw;
        }
    }
}
