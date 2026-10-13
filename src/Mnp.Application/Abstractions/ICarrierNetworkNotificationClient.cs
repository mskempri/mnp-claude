namespace Mnp.Application.Abstractions;

public interface ICarrierNetworkNotificationClient
{
    Task NotifyAsync(
        string networkCode,
        string eventType,
        string msisdn,
        CancellationToken cancellationToken);
}
