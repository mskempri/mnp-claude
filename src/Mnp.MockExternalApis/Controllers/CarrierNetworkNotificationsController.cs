using Microsoft.AspNetCore.Mvc;

namespace Mnp.MockExternalApis.Controllers;

/// <summary>
/// Dev-only stand-in for a donor/recipient carrier network's notification
/// intake. Matches the contract <c>Mnp.Infrastructure.ExternalApis.CarrierNetworkNotificationClient</c> calls.
/// </summary>
[ApiController]
[Route("networks/{networkCode}/notifications")]
public sealed class CarrierNetworkNotificationsController : ControllerBase
{
    [HttpPost]
    public IActionResult Notify([FromRoute] string networkCode, [FromBody] NotifyRequest request)
    {
        return Ok();
    }
}

public sealed record NotifyRequest(string EventType, string Msisdn);
