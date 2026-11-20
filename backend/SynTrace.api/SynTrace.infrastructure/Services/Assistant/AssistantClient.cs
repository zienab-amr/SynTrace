using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Infrastructure.Options;

namespace SynTrace.Infrastructure.Services.Assistant;

/// <summary>Calls the AI service. Question and answer text must never be logged.</summary>
public sealed class AssistantClient : IAssistantClient
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly AiServiceOptions _options;
    private readonly ILogger<AssistantClient> _logger;

    public AssistantClient(
        IHttpClientFactory httpClientFactory,
        IOptions<AiServiceOptions> options,
        ILogger<AssistantClient> logger)
    {
        _httpClientFactory = httpClientFactory;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<AssistantResult> AskAsync(
        string question,
        string companyId,
        string employeeId,
        IReadOnlyList<string> allowedProjects,
        string correlationId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.BaseUrl) || string.IsNullOrWhiteSpace(_options.ApiKey))
        {
            _logger.LogError("AiService:BaseUrl or AiService:ApiKey is not set.");
            return new(null, AssistantFailure.Misconfigured);
        }

        using var request = new HttpRequestMessage(HttpMethod.Post, $"{_options.BaseUrl.TrimEnd('/')}/ask")
        {
            Content = JsonContent.Create(new { question, companyId, employeeId, allowedProjects })
        };
        request.Headers.Add("X-Internal-Api-Key", _options.ApiKey);
        request.Headers.Add("X-Correlation-Id", correlationId);

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));

        try
        {
            var client = _httpClientFactory.CreateClient();
            client.Timeout = Timeout.InfiniteTimeSpan;   // the linked token above is the only timeout
            using var response = await client.SendAsync(request, timeout.Token);

            if (response.IsSuccessStatusCode)
            {
                var answer = await response.Content.ReadFromJsonAsync<AssistantAnswer>(timeout.Token);
                return answer is null ? new(null, AssistantFailure.Unavailable) : new(answer, AssistantFailure.None);
            }

            _logger.LogWarning("AI service returned {Status} (correlation {CorrelationId}).",
                (int)response.StatusCode, correlationId);

            return response.StatusCode switch
            {
                HttpStatusCode.BadRequest or HttpStatusCode.UnprocessableEntity => new(null, AssistantFailure.BadRequest),
                HttpStatusCode.Unauthorized => new(null, AssistantFailure.Misconfigured),
                _ => new(null, AssistantFailure.Unavailable)
            };
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning("AI service timed out (correlation {CorrelationId}).", correlationId);
            return new(null, AssistantFailure.Unavailable);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning("AI service is unreachable: {Error} (correlation {CorrelationId}).",
                ex.GetType().Name, correlationId);
            return new(null, AssistantFailure.Unavailable);
        }
    }
}
