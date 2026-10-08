using Mnp.Domain;

namespace Mnp.Infrastructure.Database;

/// <summary>
/// Maps the .NET enum to the VARCHAR2 codes enforced by the CHECK constraint
/// on MNP_PORTING_REQUESTS.STATUS (see database/schema/001_create_porting_requests_table.sql).
/// </summary>
internal static class PortingStatusMapping
{
    public static string ToCode(PortingStatus status) => status switch
    {
        PortingStatus.Received => "RECEIVED",
        PortingStatus.Validating => "VALIDATING",
        PortingStatus.Approved => "APPROVED",
        PortingStatus.Rejected => "REJECTED",
        PortingStatus.Scheduled => "SCHEDULED",
        PortingStatus.Completed => "COMPLETED",
        PortingStatus.Cancelled => "CANCELLED",
        _ => throw new ArgumentOutOfRangeException(nameof(status), status, null)
    };

    public static PortingStatus FromCode(string code) => code switch
    {
        "RECEIVED" => PortingStatus.Received,
        "VALIDATING" => PortingStatus.Validating,
        "APPROVED" => PortingStatus.Approved,
        "REJECTED" => PortingStatus.Rejected,
        "SCHEDULED" => PortingStatus.Scheduled,
        "COMPLETED" => PortingStatus.Completed,
        "CANCELLED" => PortingStatus.Cancelled,
        _ => throw new ArgumentOutOfRangeException(nameof(code), code, "Unknown porting status code from database.")
    };
}
