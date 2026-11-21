using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts.Integrations.GitHub;
using SynTrace.Infrastructure.Integrations.GitHub;

namespace SynTrace_api.Controllers;

[ApiController]
[Authorize]
[Route("api/integrations/github")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class GitHubOAuthController(
    IGitHubOAuthService github,
    IOptions<GitHubOAuthOptions> options) : ControllerBase
{
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpGet("connect")]
    public Task<IActionResult> ConnectCompany(CancellationToken ct) =>
        RunAsync(async () => Ok(await github.StartAsync(GitHubConnectMode.InstallCompany, ct)), ct);

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpGet("authorize-company")]
    public Task<IActionResult> AuthorizeExistingCompanyInstallation(CancellationToken ct) =>
        RunAsync(async () => Ok(await github.StartAsync(GitHubConnectMode.ExistingCompanyInstallation, ct)), ct);

    [HttpGet("connect-employee")]
    public Task<IActionResult> ConnectEmployee(CancellationToken ct) =>
        RunAsync(async () => Ok(await github.StartAsync(GitHubConnectMode.EmployeeIdentity, ct)), ct);

    [AllowAnonymous]
    [HttpGet("callback")]
    public Task<IActionResult> Callback([FromQuery] string? state, [FromQuery] string? code,
        [FromQuery(Name = "setup_action")] string? setupAction, [FromQuery] string? error, CancellationToken ct) =>
        RunAsync(async () =>
        {
            Response.Headers["Referrer-Policy"] = "no-referrer";
            if (!string.IsNullOrWhiteSpace(error))
                return BadRequest(new { message = "GitHub authorization was cancelled or denied." });
            if (string.IsNullOrWhiteSpace(state) || state.Length > 128)
                return BadRequest(new { message = "GitHub did not return a valid linking state." });

            var result = await github.CallbackAsync(state, code, setupAction, ct);
            var destination = options.Value.FrontendRedirectUri;
            if (string.IsNullOrEmpty(destination))
                return Ok(result);
            if (!Uri.TryCreate(destination, UriKind.Absolute, out var frontend) ||
                !(frontend.Scheme == Uri.UriSchemeHttps || (frontend.Scheme == Uri.UriSchemeHttp && frontend.IsLoopback)) ||
                !string.IsNullOrEmpty(frontend.UserInfo))
            {
                return StatusCode(503, new { message = "The GitHub completion page is not configured." });
            }

            return Redirect(QueryHelpers.AddQueryString(destination, new Dictionary<string, string?>
            {
                ["status"] = result.Status,
                ["completionId"] = result.CompletionId
            }));
        }, ct);

    [HttpGet("pending")]
    public Task<IActionResult> Pending([FromQuery] string completionId, CancellationToken ct) =>
        RunAsync(async () => Ok(await github.PendingAsync(completionId, ct)), ct);

    [HttpPost("complete")]
    public Task<IActionResult> Complete([FromBody] CompleteGitHubConnection request, CancellationToken ct) =>
        RunAsync(async () =>
        {
            await github.CompleteAsync(request.CompletionId, request.InstallationId, ct);
            return NoContent();
        }, ct);

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpGet("company")]
    public Task<IActionResult> CompanyStatus(CancellationToken ct) =>
        RunAsync(async () => Ok(await github.CompanyStatusAsync(ct)), ct);

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpDelete("company")]
    public Task<IActionResult> DisconnectCompany(CancellationToken ct) =>
        RunAsync(async () =>
        {
            await github.DisconnectCompanyAsync(ct);
            return NoContent();
        }, ct);

    [HttpGet("employee")]
    public Task<IActionResult> EmployeeIdentity(CancellationToken ct) =>
        RunAsync(async () => Ok(await github.EmployeeStatusAsync(ct)), ct);

    [HttpDelete("employee")]
    public Task<IActionResult> DisconnectEmployee(CancellationToken ct) =>
        RunAsync(async () =>
        {
            await github.DisconnectEmployeeAsync(ct);
            return NoContent();
        }, ct);

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpGet("repositories")]
    public Task<IActionResult> Repositories(CancellationToken ct) =>
        RunAsync(async () => Ok(await github.RepositoriesAsync(ct)), ct);

    [HttpGet("projects/{projectId}")]
    public Task<IActionResult> ProjectStatus(string projectId, CancellationToken ct) =>
        RunAsync(async () => Ok(await github.ProjectStatusAsync(projectId, ct)), ct);

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpPut("projects/{projectId}/repository")]
    public Task<IActionResult> MapRepository(string projectId, [FromBody] MapGitHubRepository request, CancellationToken ct) =>
        RunAsync(async () => Ok(await github.MapRepositoryAsync(projectId, request.RepositoryId, ct)), ct);

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpDelete("projects/{projectId}/repository")]
    public Task<IActionResult> UnmapRepository(string projectId, CancellationToken ct) =>
        RunAsync(async () =>
        {
            await github.UnmapRepositoryAsync(projectId, ct);
            return NoContent();
        }, ct);

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpPost("projects/{projectId}/sync")]
    public Task<IActionResult> ResyncProject(string projectId, CancellationToken ct) =>
        RunAsync(async () =>
        {
            await github.RequestProjectSyncAsync(projectId, ct);
            return Accepted(new { status = "pending" });
        }, ct);

    private async Task<IActionResult> RunAsync(Func<Task<IActionResult>> operation, CancellationToken cancellationToken)
    {
        try
        {
            return await operation();
        }
        catch (GitHubIntegrationException exception)
        {
            return StatusCode(exception.StatusCode, new { message = exception.Message });
        }
        catch (GitHubApiException exception) when (exception.RetryAtUtc is { } retryAt)
        {
            Response.Headers.RetryAfter = retryAt.ToString("R");
            return StatusCode(503, new { message = "GitHub is rate limiting requests. Please retry later." });
        }
        catch (GitHubApiException exception) when (exception.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.UnprocessableEntity)
        {
            return StatusCode(409, new { message = "GitHub no longer grants access to that installation or repository." });
        }
        catch (GitHubApiException exception) when (exception.StatusCode == HttpStatusCode.ServiceUnavailable)
        {
            return StatusCode(503, new { message = exception.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
        catch (HttpRequestException)
        {
            return StatusCode(502, new { message = "GitHub could not complete the request. Check the connection and try again." });
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return StatusCode(504, new { message = "GitHub did not answer in time. Please try again." });
        }
    }
}

public sealed record CompleteGitHubConnection(string CompletionId, long? InstallationId);
public sealed record MapGitHubRepository(long RepositoryId);
