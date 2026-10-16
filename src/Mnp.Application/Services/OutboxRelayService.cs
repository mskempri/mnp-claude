using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;
using Mnp.Domain;

namespace Mnp.Application.Services;

public sealed class OutboxRelayService(
    IOutboxRepository repository,
    ICarrierNetworkNotificationClient carrierNetworkNotificationClient,
    ICustomerNotificationClient customerNotificationClient,
    ILogger<OutboxRelayService> logger)
{
    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var outboxEvent = await repository.ClaimNextPendingEventAsync(cancellationToken);
        if (outboxEvent is null)
        {
            return false;
        }

        try
        {
            await DispatchAsync(outboxEvent, cancellationToken);
            await repository.MarkPublishedAsync(outboxEvent.Id, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Failed to dispatch outbox event {OutboxEventId} ({EventType}, audience {Audience}) for request {RequestId}",
                outboxEvent.Id, outboxEvent.EventType, outboxEvent.Audience, outboxEvent.RequestId);
            await repository.MarkFailedAsync(outboxEvent.Id, ex.Message, cancellationToken);
        }

        return true;
    }

    private async Task DispatchAsync(OutboxEvent outboxEvent, CancellationToken cancellationToken)
    {
        switch (outboxEvent.Audience)
        {
            case NotificationAudience.DonorNetwork:
                await carrierNetworkNotificationClient.NotifyAsync(
                    outboxEvent.DonorNetworkCode, outboxEvent.EventType, outboxEvent.Msisdn, cancellationToken);
                break;

            case NotificationAudience.RecipientNetwork:
                await carrierNetworkNotificationClient.NotifyAsync(
                    outboxEvent.RecipientNetworkCode, outboxEvent.EventType, outboxEvent.Msisdn, cancellationToken);
                break;

            case NotificationAudience.Customer:
                await customerNotificationClient.NotifyAsync(
                    outboxEvent.Msisdn, outboxEvent.EventType, cancellationToken);
                break;

            case NotificationAudience.Operations:
                logger.LogWarning(
                    "Operations notification: {EventType} for request {RequestId} (msisdn {Msisdn})",
                    outboxEvent.EventType, outboxEvent.RequestId, outboxEvent.Msisdn);
                break;

            default:
                throw new ArgumentOutOfRangeException(
                    nameof(outboxEvent), outboxEvent.Audience, "Unknown notification audience.");
        }
    }
}
