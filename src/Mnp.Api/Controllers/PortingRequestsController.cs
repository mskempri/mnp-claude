using Microsoft.AspNetCore.Mvc;
using Mnp.Application.Services;
using Mnp.Domain;

namespace Mnp.Api.Controllers;

[ApiController]
[Route("api/porting-requests")]
public sealed class PortingRequestsController(PortingRequestService service, ILogger<PortingRequestsController> logger) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<PortingRequest>> Submit(
        [FromBody] SubmitPortingRequest request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Received porting request submission: {DonorNetworkCode} -> {RecipientNetworkCode}",
            request.DonorNetworkCode, request.RecipientNetworkCode);

        var created = await service.SubmitAsync(
            request.Msisdn,
            request.DonorNetworkCode,
            request.RecipientNetworkCode,
            request.RequestedPortingDate,
            request.PacCode,
            request.PacIssuedDate,
            cancellationToken);

        logger.LogInformation("Porting request {RequestId} created with status {Status}", created.Id, created.Status);

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

    [HttpPost("{id:long}/events")]
    public async Task<ActionResult<PortingRequest>> RaiseEvent(
        long id,
        [FromBody] RaisePortingRequestEvent request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation("Raising event {EventType} on porting request {RequestId}", request.EventType, id);
        var updated = await service.RaiseEventAsync(id, request.EventType, request.Context, cancellationToken);
        return Ok(updated);
    }
}

public sealed record SubmitPortingRequest(
    string Msisdn,
    string DonorNetworkCode,
    string RecipientNetworkCode,
    DateOnly RequestedPortingDate,
    string PacCode,
    DateOnly PacIssuedDate);

public sealed record RaisePortingRequestEvent(string EventType, string? Context);
