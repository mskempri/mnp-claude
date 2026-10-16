namespace Mnp.Domain;

/// <summary>
/// Mirrors the MNP_OUTBOX_EVENTS.STATUS check constraint in the database.
/// </summary>
public enum OutboxEventStatus
{
    Pending,
    Claimed,
    Published,
    Failed,
    DeadLetter
}
