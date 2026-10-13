using Mnp.Domain;

namespace Mnp.Infrastructure.Database;

internal static class NotificationAudienceMapping
{
    public static NotificationAudience FromCode(string code) => code switch
    {
        "DONOR_NETWORK" => NotificationAudience.DonorNetwork,
        "RECIPIENT_NETWORK" => NotificationAudience.RecipientNetwork,
        "CUSTOMER" => NotificationAudience.Customer,
        "OPERATIONS" => NotificationAudience.Operations,
        _ => throw new ArgumentOutOfRangeException(nameof(code), code, "Unknown notification audience code from database.")
    };
}
