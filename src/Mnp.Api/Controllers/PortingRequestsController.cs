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

    /// <summary>
    /// Raises an event (e.g. SCHEDULE, CANCEL, CUTOVER_COMPLETE) against the
    /// request's current status. The resulting status is decided entirely by
    /// the database's rule engine - this endpoint has no notion of "valid
    /// transitions" itself. An event with no matching branch for the
    /// request's current status surfaces as a database error (500), not a
    /// distinct 4xx - translating that cleanly is a follow-up, not Phase A scope.
    /// </summary>
    [HttpPost("{id:long}/events")]
    public async Task<ActionResult<PortingRequest>> RaiseEvent(
        long id,
        [FromBody] RaisePortingRequestEvent request,
        CancellationToken cancellationToken)
    {
        var updated = await service.RaiseEventAsync(id, request.EventType, request.Context, cancellationToken);
        return Ok(updated);
    }
}

public sealed record SubmitPortingRequest(
    string Msisdn,
    string DonorNetworkCode,
    string RecipientNetworkCode,
    DateOnly RequestedPortingDate);

public sealed record RaisePortingRequestEvent(string EventType, string? Context);
