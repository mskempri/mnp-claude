using Microsoft.AspNetCore.Mvc;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Api.Controllers;

[ApiController]
[Route("api/porting-requests")]
public sealed class PortingRequestsController(PortingRequestService service) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<PortingRequest>> Submit(
        [FromBody] SubmitPortingRequest request,
        CancellationToken cancellationToken)
    {
        var created = await service.SubmitAsync(
            request.Msisdn,
            request.DonorNetworkCode,
            request.RecipientNetworkCode,
            request.RequestedPortingDate,
            cancellationToken);

        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpGet("{id:long}")]
    public async Task<ActionResult<PortingRequest>> GetById(long id, CancellationToken cancellationToken)
    {
        var request = await service.GetAsync(id, cancellationToken);
        return request is null ? NotFound() : Ok(request);
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PortingRequest>>> GetByMsisdn(
        [FromQuery] string msisdn,
        CancellationToken cancellationToken)
    {
        var requests = await service.GetByMsisdnAsync(msisdn, cancellationToken);
        return Ok(requests);
    }
}

public sealed record SubmitPortingRequest(
    string Msisdn,
    string DonorNetworkCode,
    string RecipientNetworkCode,
    DateOnly RequestedPortingDate);
