using System.Data;
using System.Text.Json;
using Mnp.Application.Abstractions;
using Mnp.Domain;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Mnp.Infrastructure.Database;

public sealed class OutboxRepository(IDbConnectionFactory connectionFactory) : IOutboxRepository
{
    public async Task<OutboxEvent?> ClaimNextPendingEventAsync(CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_OUTBOX.PR_CLAIM_NEXT_PENDING";
        command.BindByName = true;

        command.Parameters.Add("p_cursor", OracleDbType.RefCursor, DBNull.Value, ParameterDirection.Output);

        await command.ExecuteNonQueryAsync(cancellationToken);
        var cursor = (OracleRefCursor)command.Parameters["p_cursor"].Value;
        await using var reader = cursor.GetDataReader();

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var id = reader.GetInt64(reader.GetOrdinal("ID"));

        try
        {
            var eventType = reader.GetString(reader.GetOrdinal("EVENT_TYPE"));
            var audienceOrdinal = reader.GetOrdinal("AUDIENCE");
            if (reader.IsDBNull(audienceOrdinal))
            {
                throw new InvalidOperationException(
                    "Outbox row has no audience classification (likely predates the audience column).");
            }

            var audience = NotificationAudienceMapping.FromCode(reader.GetString(audienceOrdinal));
            var payload = reader.GetString(reader.GetOrdinal("PAYLOAD"));

            using var json = JsonDocument.Parse(payload);
            var root = json.RootElement;

            return new OutboxEvent
            {
                Id = id,
                RequestId = root.GetProperty("requestId").GetInt64(),
                EventType = eventType,
                Audience = audience,
                Msisdn = root.GetProperty("msisdn").GetString()!,
                DonorNetworkCode = root.GetProperty("donorNetworkCode").GetString()!,
                RecipientNetworkCode = root.GetProperty("recipientNetworkCode").GetString()!
            };
        }
        catch (Exception ex)
        {
            await MarkFailedAsync(id, $"Claimed row could not be parsed for dispatch: {ex.Message}", cancellationToken);
            return null;
        }
    }

    public async Task MarkPublishedAsync(long outboxId, CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_OUTBOX.PR_MARK_PUBLISHED";
        command.BindByName = true;

        command.Parameters.Add("p_outbox_id", OracleDbType.Int64, outboxId, ParameterDirection.Input);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task MarkFailedAsync(long outboxId, string error, CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_OUTBOX.PR_MARK_FAILED";
        command.BindByName = true;

        command.Parameters.Add("p_outbox_id", OracleDbType.Int64, outboxId, ParameterDirection.Input);
        command.Parameters.Add("p_error", OracleDbType.Varchar2, error, ParameterDirection.Input);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
