using Mnp.Domain;

namespace Mnp.Application.Abstractions;

public interface INumberRegistryRepository
{
    Task<NumberOwnership?> LookupAsync(string msisdn, CancellationToken cancellationToken);
}
