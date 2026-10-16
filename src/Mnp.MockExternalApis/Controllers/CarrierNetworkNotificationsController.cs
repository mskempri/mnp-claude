using Microsoft.AspNetCore.Mvc;

namespace Mnp.MockExternalApis.Controllers;

[ApiController]
[Route("networks/{networkCode}/notifications")]
public sealed class CarrierNetworkNotificationsController(ILogger<CarrierNetworkNotificationsController> logger) : ControllerBase
{
    [HttpPost]
    public IActionResult Notify([FromRoute] string networkCode, [FromBody] NotifyRequest request)
    {
        logger.LogInformation(
            "Mock: received notification {EventType} for network {NetworkCode}", request.EventType, networkCode);
        return Ok();
    }
}

public sealed record NotifyRequest(string EventType, string Msisdn);
