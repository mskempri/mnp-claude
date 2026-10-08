using Mnp.Application.Abstractions;
using Mnp.Application.Services;
using Mnp.Infrastructure.Database;
using Mnp.Infrastructure.ExternalApis;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddScoped<IDbConnectionFactory, OracleConnectionFactory>();
builder.Services.AddScoped<IPortingRequestRepository, PortingRequestRepository>();
builder.Services.AddScoped<PortingRequestService>();

builder.Services
    .AddOptions<CarrierNetworkOptions>()
    .Bind(builder.Configuration.GetSection(CarrierNetworkOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services
    .AddHttpClient<ICarrierNetworkClient, CarrierNetworkClient>((sp, client) =>
    {
        var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<CarrierNetworkOptions>>().Value;
        client.BaseAddress = options.BaseUrl;
    })
    .AddStandardResilienceHandler();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
