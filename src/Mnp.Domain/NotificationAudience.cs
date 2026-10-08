namespace Mnp.Domain;

/// <summary>
/// Mirrors MNP_OUTBOX_EVENTS.AUDIENCE / MNP_NOTIFICATION_TYPES.AUDIENCE.
/// Who an outbox event is for, decided entirely in PL/SQL (PKG_OUTBOX) from
/// the MNP_NOTIFICATION_TYPES registry — this enum only tracks the result.
/// </summary>
public enum NotificationAudience
{
    DonorNetwork,
    RecipientNetwork,
    Customer,
    Operations
}
