using Microsoft.AspNetCore.Mvc;

namespace Mnp.MockExternalApis.Controllers;

/// <summary>
/// Dev-only stand-in for a real donor/carrier network's subscriber-validation
/// API. Matches the contract <c>Mnp.Infrastructure.ExternalApis.CarrierNetworkClient</c>
/// calls, so local testing exercises the real HTTP round trip instead of a
/// placeholder host that only ever fails DNS resolution.
/// </summary>
[ApiController]
[Route("networks/{networkCode}/subscribers")]
public sealed class DonorNetworkController(ILogger<DonorNetworkController> logger) : ControllerBase
{
    // Deterministic test hook: any MSISDN ending in "0000" is reported
    // ineligible, so both the success and failure paths are reachable
    // without a stateful mock configuration endpoint.
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
