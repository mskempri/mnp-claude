using Microsoft.AspNetCore.Mvc;

namespace Mnp.MockExternalApis.Controllers;

[ApiController]
[Route("networks/{networkCode}/subscribers")]
public sealed class DonorNetworkController(ILogger<DonorNetworkController> logger) : ControllerBase
{
    private const string IneligibleMsisdnSuffix = "0000";

    [HttpPost("validate")]
    public ActionResult<ValidateSubscriberResponse> Validate(
        [FromRoute] string networkCode,
        [FromBody] ValidateSubscriberRequest request)
    {
        var isEligible = !request.Msisdn.EndsWith(IneligibleMsisdnSuffix, StringComparison.Ordinal);

        logger.LogInformation(
            "Mock: validated subscriber for network {NetworkCode}, result: {Eligibility}",
            networkCode, isEligible ? "eligible" : "ineligible");

        return Ok(new ValidateSubscriberResponse(
            isEligible,
            isEligible ? null : $"Mock donor network {networkCode}: subscriber {request.Msisdn} is barred."));
    }
}

public sealed record ValidateSubscriberRequest(string Msisdn);

public sealed record ValidateSubscriberResponse(bool IsEligible, string? DenialReason);
