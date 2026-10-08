namespace Mnp.Domain;

/// <summary>
/// Mirrors the MNP_PORTING_REQUESTS.STATUS check constraint in the database.
/// The database is the source of truth for which transitions are legal.
/// </summary>
public enum PortingStatus
{
    Received,
    Validating,
    Approved,
    Rejected,
    Scheduled,
    Completed,
    Cancelled
}
