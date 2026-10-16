using Microsoft.AspNetCore.Mvc;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Api.Controllers;

[ApiController]
[Route("api/outbox")]
public sealed class OutboxController(OutboxQueryService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<OutboxEventSummary>>> GetRecent(
        [FromQuery] int limit,
        CancellationToken cancellationToken)
    {
        var effectiveLimit = limit is > 0 and <= 200 ? limit : 25;
        var events = await service.GetRecentAsync(effectiveLimit, cancellationToken);
        return Ok(events);
    }
}
