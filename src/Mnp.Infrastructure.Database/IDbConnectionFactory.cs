using Oracle.ManagedDataAccess.Client;

namespace Mnp.Infrastructure.Database;

public interface IDbConnectionFactory
{
    Task<OracleConnection> CreateOpenConnectionAsync(CancellationToken cancellationToken);
}
