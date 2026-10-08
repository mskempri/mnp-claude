namespace Mnp.Domain;

/// <summary>
/// Mirrors the MNP_PORTING_REQUESTS.STATUS check constraint in the database.
/// The database (PKG_WORKFLOW_ENGINE, driven by MNP_WORKFLOW_BRANCHES) is the
/// sole source of truth for which transitions are legal; this enum only
/// tracks what the database already decided.
/// </summary>
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
