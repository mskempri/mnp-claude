namespace Mnp.Domain;

public enum PortingStatus
{
    Received,
    Validating,
    Approved,
    Rejected,
    Scheduled,
    Cutover,
    Completed,
    Cancelled
}
