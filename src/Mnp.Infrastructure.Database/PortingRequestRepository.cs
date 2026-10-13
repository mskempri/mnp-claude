using System.Data;
using Mnp.Application.Abstractions;
using Mnp.Domain;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Mnp.Infrastructure.Database;

public sealed class PortingRequestRepository(IDbConnectionFactory connectionFactory) : IPortingRequestRepository
{
    public async Task<long> CreateAsync(
        string msisdn,
        string donorNetworkCode,
        string recipientNetworkCode,
        DateOnly requestedPortingDate,
        string pacCode,
        DateOnly pacIssuedDate,
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
        command.Parameters.Add("p_pac_code", OracleDbType.Varchar2, pacCode, ParameterDirection.Input);
        command.Parameters.Add("p_pac_issued_date", OracleDbType.Date, pacIssuedDate.ToDateTime(TimeOnly.MinValue), ParameterDirection.Input);

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

    public async Task RaiseEventAsync(
        long id,
        string eventType,
        string? context,
        CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_PORTING_REQUESTS.PR_RAISE_EVENT";
        command.BindByName = true;

        command.Parameters.Add("p_id", OracleDbType.Int64, id, ParameterDirection.Input);
        command.Parameters.Add("p_event_type", OracleDbType.Varchar2, eventType, ParameterDirection.Input);
        command.Parameters.Add("p_context", OracleDbType.Varchar2, (object?)context ?? DBNull.Value, ParameterDirection.Input);

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
        PacCode = reader.IsDBNull(reader.GetOrdinal("PAC_CODE"))
            ? null
            : reader.GetString(reader.GetOrdinal("PAC_CODE")),
        PacIssuedDate = reader.IsDBNull(reader.GetOrdinal("PAC_ISSUED_DATE"))
            ? null
            : DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("PAC_ISSUED_DATE"))),
        CreatedAt = new DateTimeOffset(reader.GetDateTime(reader.GetOrdinal("CREATED_AT"))),
        UpdatedAt = new DateTimeOffset(reader.GetDateTime(reader.GetOrdinal("UPDATED_AT")))
    };
}
