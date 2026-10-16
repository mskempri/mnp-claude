using System.Data;
using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;
using Mnp.Domain;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Mnp.Infrastructure.Database;

/// <summary>
/// Calls PKG_NUMBER_REGISTRY (see database/packages). Read-only - the
/// registry is only ever written by the workflow engine.
/// </summary>
public sealed class NumberRegistryRepository(IDbConnectionFactory connectionFactory, ILogger<NumberRegistryRepository> logger)
    : INumberRegistryRepository
{
    public async Task<NumberOwnership?> LookupAsync(string msisdn, CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_NUMBER_REGISTRY.PR_LOOKUP";
        command.BindByName = true;

        command.Parameters.Add("p_msisdn", OracleDbType.Varchar2, msisdn, ParameterDirection.Input);
        command.Parameters.Add("p_cursor", OracleDbType.RefCursor, DBNull.Value, ParameterDirection.Output);

        await command.ExecuteNonQueryAsync(cancellationToken);
        var cursor = (OracleRefCursor)command.Parameters["p_cursor"].Value;
        await using var reader = cursor.GetDataReader();

        if (!await reader.ReadAsync(cancellationToken))
        {
            logger.LogInformation("Number registry lookup: no record found");
            return null;
        }

        var ownership = new NumberOwnership
        {
            Msisdn = reader.GetString(reader.GetOrdinal("MSISDN")),
            CurrentNetworkCode = reader.GetString(reader.GetOrdinal("CURRENT_NETWORK_CODE")),
            LastPortedAt = new DateTimeOffset(reader.GetDateTime(reader.GetOrdinal("LAST_PORTED_AT"))),
            LastPortingRequestId = reader.IsDBNull(reader.GetOrdinal("LAST_PORTING_REQUEST_ID"))
                ? null
                : reader.GetInt64(reader.GetOrdinal("LAST_PORTING_REQUEST_ID"))
        };

        logger.LogInformation("Number registry lookup: found record for network {CurrentNetworkCode}", ownership.CurrentNetworkCode);
        return ownership;
    }
}
