using Mnp.Domain;

namespace Mnp.Infrastructure.Database;

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
