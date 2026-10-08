namespace Mnp.Application.Abstractions;

/// <summary>
/// Notifies a carrier network (donor or recipient — the network code is a
/// runtime argument, not a different contract) of a porting-request event.
/// </summary>
public interface ICarrierNetworkNotificationClient
{
    Task NotifyAsync(
        string networkCode,
        string eventType,
        string msisdn,
        CancellationToken cancellationToken);
}
