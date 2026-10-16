using Microsoft.AspNetCore.Mvc;

namespace Mnp.MockExternalApis.Controllers;

[ApiController]
[Route("customers/{msisdn}/notifications")]
public sealed class CustomerNotificationsController(ILogger<CustomerNotificationsController> logger) : ControllerBase
{
    [HttpPost]
    public IActionResult Notify([FromRoute] string msisdn, [FromBody] CustomerNotifyRequest request)
    {
        logger.LogInformation("Mock: received customer notification {EventType}", request.EventType);
        return Ok();
    }
}

public sealed record CustomerNotifyRequest(string EventType);
