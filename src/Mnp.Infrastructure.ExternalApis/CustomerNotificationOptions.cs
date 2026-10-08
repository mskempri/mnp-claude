namespace Mnp.Infrastructure.ExternalApis;

public sealed class CustomerNotificationOptions
{
    public const string SectionName = "CustomerNotifications";

    public required Uri BaseUrl { get; init; }
}
