using Mnp.Domain;

namespace Mnp.Application.Abstractions;

/// <summary>
/// Gateway to the PL/SQL package that owns the number-ownership registry
/// (PKG_NUMBER_REGISTRY). Read-only from .NET's perspective - the registry is
/// only ever written by the workflow engine's RECORD_NUMBER_OWNERSHIP action.
/// </summary>
public interface INumberRegistryRepository
{
    /// <summary>
    /// Returns null if the MSISDN has never completed a port through this
    /// system - a valid "not tracked" answer, not an error.
    /// </summary>
    Task<NumberOwnership?> LookupAsync(string msisdn, CancellationToken cancellationToken);
}
