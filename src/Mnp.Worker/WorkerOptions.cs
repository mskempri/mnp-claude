namespace Mnp.Worker;

/// <summary>
/// Ops/performance tuning, not a regulatory value — appsettings config is
/// appropriate here (unlike timer durations, which are PL/SQL data).
/// </summary>
public sealed class OutboxRelayOptions
{
    public const string SectionName = "OutboxRelay";

    public int PollIntervalSeconds { get; init; } = 5;
}
