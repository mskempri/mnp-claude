using Microsoft.Extensions.Options;
using Mnp.Application.Abstractions;
using Mnp.Application.Services;
using Mnp.Infrastructure.Database;
using Mnp.Infrastructure.ExternalApis;
using Mnp.Worker;

var builder = Host.CreateApplicationBuilder(args);

// No per-request concept exists in a worker process, so these are
// singletons rather than the scoped lifetime Mnp.Api uses — they're
// stateless (a fresh OracleConnection is opened per call regardless).
builder.Services.AddSingleton<IDbConnectionFactory, OracleConnectionFactory>();
builder.Services.AddSingleton<IOutboxRepository, OutboxRepository>();
builder.Services.AddSingleton<OutboxRelayService>();

builder.Services
    .AddOptions<OutboxRelayOptions>()
    .Bind(builder.Configuration.GetSection(OutboxRelayOptions.SectionName));

builder.Services
    .AddOptions<CarrierNetworkNotificationOptions>()
    .Bind(builder.Configuration.GetSection(CarrierNetworkNotificationOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services
    .AddOptions<CustomerNotificationOptions>()
    .Bind(builder.Configuration.GetSection(CustomerNotificationOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services
    .AddHttpClient<ICarrierNetworkNotificationClient, CarrierNetworkNotificationClient>((sp, client) =>
    {
        var options = sp.GetRequiredService<IOptions<CarrierNetworkNotificationOptions>>().Value;
        client.BaseAddress = options.BaseUrl;
    })
    .AddStandardResilienceHandler();

builder.Services
    .AddHttpClient<ICustomerNotificationClient, CustomerNotificationClient>((sp, client) =>
    {
        var options = sp.GetRequiredService<IOptions<CustomerNotificationOptions>>().Value;
        client.BaseAddress = options.BaseUrl;
    })
    .AddStandardResilienceHandler();

builder.Services.AddHostedService<OutboxRelayWorker>();

var host = builder.Build();
host.Run();
