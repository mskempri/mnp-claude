namespace Mnp.Domain;

public enum OutboxEventStatus
{
    Pending,
    Claimed,
    Published,
    Failed,
    DeadLetter
}
