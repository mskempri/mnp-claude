using Microsoft.AspNetCore.Mvc;

namespace Mnp.MockExternalApis.Controllers;

[ApiController]
[Route("customers/{msisdn}/notifications")]
public sealed class CustomerNotificationsController : ControllerBase
{
    [HttpPost]
    public IActionResult Notify([FromRoute] string msisdn, [FromBody] CustomerNotifyRequest request)
    {
        return Ok();
    }
}

public sealed record CustomerNotifyRequest(string EventType);
