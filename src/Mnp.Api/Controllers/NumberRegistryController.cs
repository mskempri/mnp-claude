using Microsoft.AspNetCore.Mvc;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Api.Controllers;

[ApiController]
[Route("api/number-ownership")]
public sealed class NumberRegistryController(NumberRegistryService service) : ControllerBase
{
    /// <summary>
    /// 404 means "not tracked" - this MSISDN has never completed a port
    /// through this system, not that it has no owner.
    /// </summary>
    [HttpGet("{msisdn}")]
    public async Task<ActionResult<NumberOwnership>> GetByMsisdn(string msisdn, CancellationToken cancellationToken)
    {
        var ownership = await service.LookupAsync(msisdn, cancellationToken);
        return ownership is null ? NotFound() : Ok(ownership);
    }
}
