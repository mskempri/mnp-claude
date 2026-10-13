namespace Mnp.Infrastructure.ExternalApis;

public sealed class CarrierNetworkNotificationOptions
{
    public const string SectionName = "CarrierNetworkNotifications";

    public required Uri BaseUrl { get; init; }
}
