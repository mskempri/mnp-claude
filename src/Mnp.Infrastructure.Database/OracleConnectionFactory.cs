using Microsoft.Extensions.Configuration;
using Oracle.ManagedDataAccess.Client;

namespace Mnp.Infrastructure.Database;

public sealed class OracleConnectionFactory(IConfiguration configuration) : IDbConnectionFactory
{
    private readonly string _connectionString =
        configuration.GetConnectionString("Oracle")
        ?? throw new InvalidOperationException("Missing ConnectionStrings:Oracle configuration.");

    public async Task<OracleConnection> CreateOpenConnectionAsync(CancellationToken cancellationToken)
    {
        var connection = new OracleConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }
}
