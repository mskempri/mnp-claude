using Microsoft.AspNetCore.Mvc;

namespace Mnp.MockExternalApis.Controllers;

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
