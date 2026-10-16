using Microsoft.Extensions.Logging;
using Mnp.Application.Abstractions;
using Mnp.Domain;

namespace Mnp.Application.Services;

public sealed class NumberRegistryService(INumberRegistryRepository repository, ILogger<NumberRegistryService> logger)
{
    public async Task<NumberOwnership?> LookupAsync(string msisdn, CancellationToken cancellationToken)
    {
        logger.LogInformation("Looking up number ownership");
        return await repository.LookupAsync(msisdn, cancellationToken);
    }
}
