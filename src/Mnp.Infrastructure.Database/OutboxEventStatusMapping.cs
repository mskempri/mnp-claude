using Mnp.Domain;

namespace Mnp.Infrastructure.Database;

/// <summary>
/// Maps the .NET enum to the VARCHAR2 codes enforced by the CHECK constraint
/// on MNP_OUTBOX_EVENTS.STATUS (see database/schema/002_create_workflow_engine_tables.sql).
/// </summary>
internal static class OutboxEventStatusMapping
{
    public static OutboxEventStatus FromCode(string code) => code switch
    {
        "PENDING" => OutboxEventStatus.Pending,
        "CLAIMED" => OutboxEventStatus.Claimed,
        "PUBLISHED" => OutboxEventStatus.Published,
        "FAILED" => OutboxEventStatus.Failed,
        "DEAD_LETTER" => OutboxEventStatus.DeadLetter,
        _ => throw new ArgumentOutOfRangeException(nameof(code), code, "Unknown outbox event status code from database.")
    };
}
