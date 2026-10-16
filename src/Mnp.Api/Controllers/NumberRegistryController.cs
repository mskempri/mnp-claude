using Microsoft.AspNetCore.Mvc;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Api.Controllers;

[ApiController]
[Route("api/number-ownership")]
public sealed class NumberRegistryController(NumberRegistryService service, ILogger<NumberRegistryController> logger) : ControllerBase
{
    [HttpGet("{msisdn}")]
    public async Task<ActionResult<NumberOwnership>> GetByMsisdn(string msisdn, CancellationToken cancellationToken)
    {
        var ownership = await service.LookupAsync(msisdn, cancellationToken);
        if (ownership is null)
        {
            logger.LogInformation("No ownership record found for requested MSISDN");
            return NotFound();
        }

        return Ok(ownership);
    }
}
