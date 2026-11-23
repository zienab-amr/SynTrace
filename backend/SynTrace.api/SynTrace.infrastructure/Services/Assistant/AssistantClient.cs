using System.Text.Json;
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
    public const string HttpClientName = "SynTrace.Assistant";
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
        AssistantProjectScope scope,
        string correlationId,
        string? jiraAccountId,
        string conversationId,
        IReadOnlyList<AssistantHistoryTurn> history,
        IReadOnlyList<string> addedTo,
        IReadOnlyList<string> quotedExcerpts,
        bool clearAiMemory,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.BaseUrl) || string.IsNullOrWhiteSpace(_options.ApiKey))
        {
            _logger.LogError("AiService:BaseUrl or AiService:ApiKey is not set.");
            return new(null, AssistantFailure.Misconfigured);
        }

        var payload = new Dictionary<string, object>
        {
            ["question"] = question,
            ["companyId"] = companyId,
            ["employeeId"] = employeeId,
            ["allowedProjects"] = scope.JiraKeys,
            ["jiraAccountId"] = jiraAccountId!,
            ["conversationId"] = conversationId,
            // The AI accepts question/answer pairs in chronological order.
            ["history"] = history.Select(turn => new { question = turn.Question, answer = turn.Answer }).ToArray(),
            ["addedTo"] = addedTo,
            // Selected excerpts are extra context, NOT completed chat turns.
            ["quotedExcerpts"] = quotedExcerpts
        };
        // When history is empty after an edit, AI's in-process memory must be cleared.
        // In the currently deployed AI implementation, [] falls back to process memory.
        if (clearAiMemory) payload["editedTurns"] = 50;
        if (_options.EnableSynTraceProjectScope)
            payload["allowedSynTraceProjectIds"] = scope.SynTraceProjectIds;

        using var request = new HttpRequestMessage(HttpMethod.Post, $"{_options.BaseUrl.TrimEnd('/')}/ask")
        {
            Content = JsonContent.Create(payload)
        };
        request.Headers.Add("X-Internal-Api-Key", _options.ApiKey);
        request.Headers.Add("X-Correlation-Id", correlationId);

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(Math.Clamp(_options.TimeoutSeconds, 1, 180)));

        try
        {
            var client = _httpClientFactory.CreateClient(HttpClientName);
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
                HttpStatusCode.Conflict => new(null, AssistantFailure.Cancelled),
                _ => new(null, AssistantFailure.Unavailable)
            };
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning("AI service timed out (correlation {CorrelationId}).", correlationId);
            await CancelAsync(correlationId, CancellationToken.None);
            return new(null, AssistantFailure.Unavailable);
        }
        catch (JsonException)
        {
            _logger.LogWarning("AI service returned an invalid response (correlation {CorrelationId}).", correlationId);
            return new(null, AssistantFailure.Unavailable);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning("AI service is unreachable: {Error} (correlation {CorrelationId}).",
                ex.GetType().Name, correlationId);
            return new(null, AssistantFailure.Unavailable);
        }
    }

    public async Task CancelAsync(string correlationId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.BaseUrl) || string.IsNullOrWhiteSpace(_options.ApiKey))
            return;
        // Independent timeout: the user's original HTTP request is often already cancelled.
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(3));
        using var request = new HttpRequestMessage(HttpMethod.Delete,
            $"{_options.BaseUrl.TrimEnd('/')}/ask/{Uri.EscapeDataString(correlationId)}");
        request.Headers.Add("X-Internal-Api-Key", _options.ApiKey);
        request.Headers.Add("X-Correlation-Id", correlationId);
        try
        {
            var client = _httpClientFactory.CreateClient(HttpClientName);
            client.Timeout = Timeout.InfiniteTimeSpan;
            using var response = await client.SendAsync(request, timeout.Token);
            if (!response.IsSuccessStatusCode)
                _logger.LogWarning("AI cancellation rejected for {CorrelationId} with {StatusCode}",
                    correlationId, (int)response.StatusCode);
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("AI cancellation timed out for {CorrelationId}", correlationId);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning("AI cancellation failed ({ExceptionType}) for {CorrelationId}",
                ex.GetType().Name, correlationId);
        }
    }
}
