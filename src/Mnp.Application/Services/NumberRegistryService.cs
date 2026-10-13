using Mnp.Application.Abstractions;
using Mnp.Domain;

namespace Mnp.Application.Services;

public sealed class NumberRegistryService(INumberRegistryRepository repository)
{
    public Task<NumberOwnership?> LookupAsync(string msisdn, CancellationToken cancellationToken) =>
        repository.LookupAsync(msisdn, cancellationToken);
}
