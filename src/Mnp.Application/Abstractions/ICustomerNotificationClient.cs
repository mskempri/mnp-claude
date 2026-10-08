namespace Mnp.Application.Abstractions;

/// <summary>
/// Notifies the subscriber (e.g. SMS/email/push gateway) of a porting-request event.
/// </summary>
public interface ICustomerNotificationClient
{
    Task NotifyAsync(
        string msisdn,
        string eventType,
        CancellationToken cancellationToken);
}
