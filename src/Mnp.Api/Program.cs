using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpLogging;
using Mnp.Api;
using Mnp.Application.Abstractions;
using Mnp.Application.Services;
using Mnp.Infrastructure.Database;
using Mnp.Infrastructure.ExternalApis;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddOpenApi();

builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddHttpLogging(options =>
{
    options.LoggingFields =
        HttpLoggingFields.RequestMethod |
        HttpLoggingFields.RequestPath |
        HttpLoggingFields.RequestQuery |
        HttpLoggingFields.ResponseStatusCode |
        HttpLoggingFields.Duration;
});

builder.Services.AddScoped<IDbConnectionFactory, OracleConnectionFactory>();
builder.Services.AddScoped<IPortingRequestRepository, PortingRequestRepository>();
builder.Services.AddScoped<PortingRequestService>();
builder.Services.AddScoped<INumberRegistryRepository, NumberRegistryRepository>();
builder.Services.AddScoped<NumberRegistryService>();
builder.Services.AddScoped<IOutboxRepository, OutboxRepository>();
builder.Services.AddScoped<OutboxQueryService>();

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

var correlationLogger = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("RequestCorrelation");

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseExceptionHandler();
app.UseHttpLogging();
app.Use(async (context, next) =>
{
    using (correlationLogger.BeginScope(new Dictionary<string, object> { ["TraceId"] = context.TraceIdentifier }))
    {
        await next();
    }
});

app.UseDefaultFiles();
app.UseStaticFiles();

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/api/health", () => Results.Ok(new { status = "ok", timeUtc = DateTimeOffset.UtcNow }));

app.Run();
