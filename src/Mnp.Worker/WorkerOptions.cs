namespace Mnp.Worker;

public sealed class OutboxRelayOptions
{
    public const string SectionName = "OutboxRelay";

    public int PollIntervalSeconds { get; init; } = 5;
}
