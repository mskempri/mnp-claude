using System.Data;
using Mnp.Application.Abstractions;
using Mnp.Domain;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Mnp.Infrastructure.Database;

/// <summary>
/// Calls PKG_PORTING_REQUESTS (see database/packages). All validation and state-transition
/// rules live in the package body — this class only shapes parameters and maps rows.
/// </summary>
public sealed class PortingRequestRepository(IDbConnectionFactory connectionFactory) : IPortingRequestRepository
{
    public async Task<long> CreateAsync(
        string msisdn,
        string donorNetworkCode,
        string recipientNetworkCode,
        DateOnly requestedPortingDate,
        CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_PORTING_REQUESTS.FN_CREATE_REQUEST";
        command.BindByName = true;

        command.Parameters.Add(new OracleParameter
        {
            OracleDbType = OracleDbType.Int64,
            Direction = ParameterDirection.ReturnValue
        });
        command.Parameters.Add("p_msisdn", OracleDbType.Varchar2, msisdn, ParameterDirection.Input);
        command.Parameters.Add("p_donor_network_code", OracleDbType.Varchar2, donorNetworkCode, ParameterDirection.Input);
        command.Parameters.Add("p_recipient_network_code", OracleDbType.Varchar2, recipientNetworkCode, ParameterDirection.Input);
        command.Parameters.Add("p_requested_porting_date", OracleDbType.Date, requestedPortingDate.ToDateTime(TimeOnly.MinValue), ParameterDirection.Input);

        await command.ExecuteNonQueryAsync(cancellationToken);

        var oracleDecimal = ((OracleDecimal)command.Parameters[0].Value);
        return oracleDecimal.ToInt64();
    }

    public async Task<PortingRequest?> GetByIdAsync(long id, CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_PORTING_REQUESTS.PR_GET_REQUEST";
        command.BindByName = true;

        command.Parameters.Add("p_id", OracleDbType.Int64, id, ParameterDirection.Input);
        command.Parameters.Add("p_cursor", OracleDbType.RefCursor, DBNull.Value, ParameterDirection.Output);

        await using var reader = await ExecuteForCursorAsync(command, "p_cursor", cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? Map(reader) : null;
    }

    public async Task<IReadOnlyList<PortingRequest>> GetByMsisdnAsync(string msisdn, CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_PORTING_REQUESTS.PR_GET_REQUESTS_BY_MSISDN";
        command.BindByName = true;

        command.Parameters.Add("p_msisdn", OracleDbType.Varchar2, msisdn, ParameterDirection.Input);
        command.Parameters.Add("p_cursor", OracleDbType.RefCursor, DBNull.Value, ParameterDirection.Output);

        await using var reader = await ExecuteForCursorAsync(command, "p_cursor", cancellationToken);

        var results = new List<PortingRequest>();
        while (await reader.ReadAsync(cancellationToken))
        {
            results.Add(Map(reader));
        }

        return results;
    }

    public async Task UpdateStatusAsync(
        long id,
        PortingStatus status,
        string? reason,
        CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_PORTING_REQUESTS.PR_UPDATE_STATUS";
        command.BindByName = true;

        command.Parameters.Add("p_id", OracleDbType.Int64, id, ParameterDirection.Input);
        command.Parameters.Add("p_status", OracleDbType.Varchar2, PortingStatusMapping.ToCode(status), ParameterDirection.Input);
        command.Parameters.Add("p_reason", OracleDbType.Varchar2, (object?)reason ?? DBNull.Value, ParameterDirection.Input);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<OracleDataReader> ExecuteForCursorAsync(
        OracleCommand command, string cursorParameterName, CancellationToken cancellationToken)
    {
        await command.ExecuteNonQueryAsync(cancellationToken);
        var cursor = (OracleRefCursor)command.Parameters[cursorParameterName].Value;
        return cursor.GetDataReader();
    }

    private static PortingRequest Map(OracleDataReader reader) => new()
    {
        Id = reader.GetInt64(reader.GetOrdinal("ID")),
        Msisdn = reader.GetString(reader.GetOrdinal("MSISDN")),
        DonorNetworkCode = reader.GetString(reader.GetOrdinal("DONOR_NETWORK_CODE")),
        RecipientNetworkCode = reader.GetString(reader.GetOrdinal("RECIPIENT_NETWORK_CODE")),
        Status = PortingStatusMapping.FromCode(reader.GetString(reader.GetOrdinal("STATUS"))),
        RequestedPortingDate = DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("REQUESTED_PORTING_DATE"))),
        RejectionReason = reader.IsDBNull(reader.GetOrdinal("REJECTION_REASON"))
            ? null
            : reader.GetString(reader.GetOrdinal("REJECTION_REASON")),
        CreatedAt = new DateTimeOffset(reader.GetDateTime(reader.GetOrdinal("CREATED_AT"))),
        UpdatedAt = new DateTimeOffset(reader.GetDateTime(reader.GetOrdinal("UPDATED_AT")))
    };
}
