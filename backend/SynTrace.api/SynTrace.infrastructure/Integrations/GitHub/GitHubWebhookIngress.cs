using System.Buffers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class GitHubWebhookIngress(
    SynTraceDbContext db,
    IConfiguration configuration,
    ILogger<GitHubWebhookIngress> logger) : IGitHubWebhookIngress
{
    // GitHub caps webhook payloads at 25 MB. Independently enforce the application limit for chunked requests.
    public const int MaxBodyBytes = 26 * 1024 * 1024;
    private const string SignaturePrefix = "sha256=";

    public async Task<GitHubWebhookReceipt> ReceiveAsync(Stream body, string? signature, string? delivery,
        string? eventName, CancellationToken cancellationToken)
    {
        var secret = configuration["GithubOAuth:WebhookSecret"];
        if (string.IsNullOrWhiteSpace(secret))
            return GitHubWebhookReceipt.Unavailable;

        if (!TryReadSignature(signature, out var signatureBytes))
            return GitHubWebhookReceipt.Unauthorized;

        using var payload = await ReadBoundedAsync(body, cancellationToken);
        if (payload is null)
            return GitHubWebhookReceipt.TooLarge;

        if (!VerifySignature(payload, secret, signatureBytes))
            return GitHubWebhookReceipt.Unauthorized;

        if (!Guid.TryParseExact(delivery, "D", out var deliveryId) || deliveryId == Guid.Empty || string.IsNullOrEmpty(eventName))
            return GitHubWebhookReceipt.Invalid;

        if (eventName == "ping")
            return GitHubWebhookReceipt.Ignored;

        if (eventName is not ("push" or "pull_request" or "repository" or "installation" or "installation_repositories"))
            return GitHubWebhookReceipt.Ignored;

        long installationId;
        long? repositoryId;
        string? action;
        try
        {
            if (!payload.TryGetBuffer(out var bytes))
                return GitHubWebhookReceipt.Invalid;
            using var document = JsonDocument.Parse(bytes.AsMemory());
            var root = document.RootElement;
            installationId = ReadId(root, "installation") ?? 0;
            action = ReadProperty(root, "action") is { ValueKind: JsonValueKind.String } actionValue
                ? actionValue.GetString()
                : null;

            if (eventName == "push" && ReadProperty(root, "ref") is not { ValueKind: JsonValueKind.String })
                return GitHubWebhookReceipt.Invalid;

            if (eventName != "push" && string.IsNullOrWhiteSpace(action))
                return GitHubWebhookReceipt.Invalid;

            if (!IsSupportedAction(eventName, action))
                return GitHubWebhookReceipt.Ignored;

            repositoryId = eventName is "installation" or "installation_repositories" ? null : ReadId(root, "repository");
        }
        catch (JsonException)
        {
            return GitHubWebhookReceipt.Invalid;
        }

        if (installationId <= 0 || (eventName is "push" or "pull_request" or "repository") && repositoryId is null)
            return GitHubWebhookReceipt.Invalid;

        var deliveries = db.Set<GitHubWebhookDelivery>();
        if (await deliveries.AnyAsync(x => x.Id == deliveryId, cancellationToken))
            return GitHubWebhookReceipt.Duplicate;

        var companyId = await db.Set<GitHubConnection>().AsNoTracking()
            .Where(x => x.InstallationId == installationId && x.IsActive)
            .Select(x => x.CompanyId)
            .SingleOrDefaultAsync(cancellationToken);
        if (companyId is null)
            return GitHubWebhookReceipt.Ignored;

        string? bindingId = null;
        if (repositoryId is not null)
        {
            bindingId = await db.Set<GitHubRepositoryBinding>().AsNoTracking()
                .Where(x => x.CompanyId == companyId && x.InstallationId == installationId && x.RepositoryId == repositoryId && x.IsActive)
                .Select(x => x.Id)
                .SingleOrDefaultAsync(cancellationToken);
            if (bindingId is null)
                return GitHubWebhookReceipt.Ignored;
        }

        var now = DateTime.UtcNow;
        var row = new GitHubWebhookDelivery
        {
            Id = deliveryId,
            CompanyId = companyId,
            InstallationId = installationId,
            RepositoryId = repositoryId,
            BindingId = bindingId,
            EventName = eventName,
            Action = action,
            ReceivedAtUtc = now,
            NextDispatchAtUtc = now
        };
        deliveries.Add(row);
        try
        {
            await db.SaveChangesAsync(cancellationToken);
            return GitHubWebhookReceipt.Accepted;
        }
        catch (DbUpdateException)
        {
            db.Entry(row).State = EntityState.Detached;
            if (await deliveries.AnyAsync(x => x.Id == deliveryId, cancellationToken))
                return GitHubWebhookReceipt.Duplicate;
            logger.LogWarning("GitHub webhook delivery {DeliveryId} could not be saved.", deliveryId);
            return GitHubWebhookReceipt.Unavailable;
        }
    }

    private static bool IsSupportedAction(string name, string? action) => name switch
    {
        "push" => action is null,
        "pull_request" => action is "opened" or "reopened" or "closed" or "edited" or "synchronize" or "ready_for_review" or "converted_to_draft",
        "repository" => action is "deleted" or "renamed" or "transferred" or "archived" or "unarchived" or "edited" or "privatized" or "publicized",
        "installation" => action is "created" or "deleted" or "suspend" or "unsuspend" or "new_permissions_accepted",
        "installation_repositories" => action is "added" or "removed",
        _ => false
    };

    private static JsonElement? ReadProperty(JsonElement document, string propertyName) =>
        document.ValueKind == JsonValueKind.Object && document.TryGetProperty(propertyName, out var value) ? value : null;

    private static long? ReadId(JsonElement document, string field) =>
        ReadProperty(document, field) is { } parent &&
        ReadProperty(parent, "id") is { ValueKind: JsonValueKind.Number } value &&
        value.TryGetInt64(out var id) && id > 0 ? id : null;

    private static bool TryReadSignature(string? signature, out byte[] bytes)
    {
        bytes = [];
        if (signature is null || !signature.StartsWith(SignaturePrefix, StringComparison.Ordinal) ||
            signature.Length != SignaturePrefix.Length + 64)
            return false;
        try
        {
            bytes = Convert.FromHexString(signature.AsSpan(SignaturePrefix.Length));
            return true;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static bool VerifySignature(MemoryStream payload, string secret, byte[] supplied)
    {
        if (!payload.TryGetBuffer(out var bytes))
            return false;
        Span<byte> digest = stackalloc byte[32];
        HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), bytes.AsSpan(), digest);
        return CryptographicOperations.FixedTimeEquals(digest, supplied);
    }

    private static async Task<MemoryStream?> ReadBoundedAsync(Stream source, CancellationToken cancellationToken)
    {
        var buffer = ArrayPool<byte>.Shared.Rent(32 * 1024);
        var target = new MemoryStream();
        try
        {
            while (true)
            {
                var count = await source.ReadAsync(buffer.AsMemory(), cancellationToken);
                if (count == 0)
                    return target;
                if (target.Length + count > MaxBodyBytes)
                {
                    target.Dispose();
                    return null;
                }
                target.Write(buffer, 0, count);
            }
        }
        catch
        {
            target.Dispose();
            throw;
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer, clearArray: true);
        }
    }
}
