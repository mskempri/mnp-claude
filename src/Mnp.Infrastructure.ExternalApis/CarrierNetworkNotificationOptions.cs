namespace Mnp.Infrastructure.ExternalApis;

/// <summary>
/// Deliberately separate from CarrierNetworkOptions (subscriber validation):
/// they hit the same mock host locally, but represent conceptually distinct
/// external calls that could have different real hosts/credentials. Sharing
/// one options type would mean changing one call's BaseUrl silently changes
/// the other's.
/// </summary>
public sealed class CarrierNetworkNotificationOptions
{
    public const string SectionName = "CarrierNetworkNotifications";

    public required Uri BaseUrl { get; init; }
}
