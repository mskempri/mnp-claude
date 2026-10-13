namespace Mnp.Application.Abstractions;

public interface ICustomerNotificationClient
{
    Task NotifyAsync(
        string msisdn,
        string eventType,
        CancellationToken cancellationToken);
}
