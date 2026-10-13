using Microsoft.Extensions.Options;
using Mnp.Application.Services;

namespace Mnp.Worker;

public sealed class OutboxRelayWorker(
    OutboxRelayService relayService,
    IOptions<OutboxRelayOptions> options,
    ILogger<OutboxRelayWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var pollInterval = TimeSpan.FromSeconds(options.Value.PollIntervalSeconds);

        while (!stoppingToken.IsCancellationRequested)
        {
            bool processedAny;
            do
            {
                processedAny = await relayService.ProcessNextAsync(stoppingToken);
            } while (processedAny && !stoppingToken.IsCancellationRequested);

            try
            {
                await Task.Delay(pollInterval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }

        logger.LogInformation("Outbox relay worker stopping.");
    }
}
