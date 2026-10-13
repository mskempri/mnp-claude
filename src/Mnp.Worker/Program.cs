using Microsoft.Extensions.Options;
using Mnp.Application.Abstractions;
using Mnp.Application.Services;
using Mnp.Infrastructure.Database;
using Mnp.Infrastructure.ExternalApis;
using Mnp.Worker;

var builder = Host.CreateApplicationBuilder(args);

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
