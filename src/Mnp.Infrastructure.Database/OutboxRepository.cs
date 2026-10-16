using System.Data;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;
using Mnp.Domain;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Mnp.Infrastructure.Database;

public sealed class OutboxRepository(IDbConnectionFactory connectionFactory, ILogger<OutboxRepository> logger) : IOutboxRepository
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

            var outboxEvent = new OutboxEvent
            {
                Id = id,
                RequestId = root.GetProperty("requestId").GetInt64(),
                EventType = eventType,
                Audience = audience,
                Msisdn = root.GetProperty("msisdn").GetString()!,
                DonorNetworkCode = root.GetProperty("donorNetworkCode").GetString()!,
                RecipientNetworkCode = root.GetProperty("recipientNetworkCode").GetString()!
            };

            logger.LogInformation("Claimed outbox event {OutboxEventId} ({EventType})", id, eventType);
            return outboxEvent;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Outbox event {OutboxEventId} could not be parsed for dispatch", id);
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
        logger.LogInformation("Marked outbox event {OutboxEventId} as published", outboxId);
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
        logger.LogWarning("Marked outbox event {OutboxEventId} as failed: {Error}", outboxId, error);
    }

    public async Task<IReadOnlyList<OutboxEventSummary>> GetRecentAsync(int limit, CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.CreateOpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "PKG_OUTBOX.PR_LIST_RECENT";
        command.BindByName = true;

        command.Parameters.Add("p_limit", OracleDbType.Int32, limit, ParameterDirection.Input);
        command.Parameters.Add("p_cursor", OracleDbType.RefCursor, DBNull.Value, ParameterDirection.Output);

        await command.ExecuteNonQueryAsync(cancellationToken);
        var cursor = (OracleRefCursor)command.Parameters["p_cursor"].Value;
        await using var reader = cursor.GetDataReader();

        var results = new List<OutboxEventSummary>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var audienceOrdinal = reader.GetOrdinal("AUDIENCE");
            var lastErrorOrdinal = reader.GetOrdinal("LAST_ERROR");
            var claimedAtOrdinal = reader.GetOrdinal("CLAIMED_AT");
            var publishedAtOrdinal = reader.GetOrdinal("PUBLISHED_AT");

            results.Add(new OutboxEventSummary
            {
                Id = reader.GetInt64(reader.GetOrdinal("ID")),
                RequestId = reader.GetInt64(reader.GetOrdinal("AGGREGATE_ID")),
                EventType = reader.GetString(reader.GetOrdinal("EVENT_TYPE")),
                Audience = reader.IsDBNull(audienceOrdinal)
                    ? null
                    : NotificationAudienceMapping.FromCode(reader.GetString(audienceOrdinal)),
                Status = OutboxEventStatusMapping.FromCode(reader.GetString(reader.GetOrdinal("STATUS"))),
                AttemptCount = reader.GetInt32(reader.GetOrdinal("ATTEMPT_COUNT")),
                LastError = reader.IsDBNull(lastErrorOrdinal) ? null : reader.GetString(lastErrorOrdinal),
                CreatedAt = new DateTimeOffset(reader.GetDateTime(reader.GetOrdinal("CREATED_AT"))),
                ClaimedAt = reader.IsDBNull(claimedAtOrdinal) ? null : new DateTimeOffset(reader.GetDateTime(claimedAtOrdinal)),
                PublishedAt = reader.IsDBNull(publishedAtOrdinal) ? null : new DateTimeOffset(reader.GetDateTime(publishedAtOrdinal))
            });
        }

        return results;
    }
}
