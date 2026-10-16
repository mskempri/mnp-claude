using Microsoft.Extensions.Logging.Abstractions;
using Mnp.Application.Abstractions;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Application.Tests;

public sealed class NumberRegistryServiceTests
{
    [Fact]
    public async Task LookupAsync_KnownMsisdn_ReturnsOwnership()
    {
        var ownership = new NumberOwnership
        {
            Msisdn = "+306900000001",
            CurrentNetworkCode = "VZW",
            LastPortedAt = DateTimeOffset.UtcNow,
            LastPortingRequestId = 42
        };
        var service = new NumberRegistryService(new FakeNumberRegistryRepository(ownership), NullLogger<NumberRegistryService>.Instance);

        var result = await service.LookupAsync("+306900000001", CancellationToken.None);

        Assert.Same(ownership, result);
    }

    [Fact]
    public async Task LookupAsync_UntrackedMsisdn_ReturnsNull()
    {
        var service = new NumberRegistryService(new FakeNumberRegistryRepository(null), NullLogger<NumberRegistryService>.Instance);

        var result = await service.LookupAsync("+306900000002", CancellationToken.None);

        Assert.Null(result);
    }

    private sealed class FakeNumberRegistryRepository(NumberOwnership? ownershipToReturn) : INumberRegistryRepository
    {
        public Task<NumberOwnership?> LookupAsync(string msisdn, CancellationToken cancellationToken) =>
            Task.FromResult(ownershipToReturn);
    }
}
