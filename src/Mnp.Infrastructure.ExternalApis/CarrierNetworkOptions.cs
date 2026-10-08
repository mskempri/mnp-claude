namespace Mnp.Infrastructure.ExternalApis;

public sealed class CarrierNetworkOptions
{
    public const string SectionName = "CarrierNetwork";

    public required Uri BaseUrl { get; init; }
}
