using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using SynTrace.Domain.Entities.GitHub;

namespace SynTrace.Infrastructure.Integrations.GitHub;

internal sealed class GitHubSyncSource(GitHubApiClient client, IOptions<GitHubSyncOptions> options)
{
    private const int PageSize = 100;
    private readonly GitHubSyncOptions _options = options.Value;

    internal static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    internal sealed record SourceItem(string Kind, string Id, string Json)
    {
        public static SourceItem Create(string kind, string id, object value)
            => new(kind, id, JsonSerializer.Serialize(value, JsonOptions));
    }

    internal sealed record Repository(string Token, long Id, string Owner, string Name, string DefaultBranch, string? HeadSha, bool IsPrivate)
    {
        public string Api => $"/repos/{Uri.EscapeDataString(Owner)}/{Uri.EscapeDataString(Name)}";
        public string Web => $"https://github.com/{Uri.EscapeDataString(Owner)}/{Uri.EscapeDataString(Name)}";
    }

    internal sealed record SourcePage(IReadOnlyList<SourceItem> Items, bool HasNextPage);
    internal sealed record CodeSnapshot(IReadOnlyList<SourceItem> Items, int SkippedFiles, string[] PartialReasons);

    public async Task<Repository?> OpenAsync(GitHubRepositoryBinding binding, CancellationToken ct)
    {
        // The wide installation token is used only to check membership, not to read repository content.
        var installationToken = await client.GetInstallationTokenAsync(binding.InstallationId, null, ct);
        var grant = await FindGrantedRepositoryAsync(binding.RepositoryId, installationToken, ct);
        if (grant is null)
            return null;

        var token = await client.GetInstallationTokenAsync(binding.InstallationId, binding.RepositoryId, ct);
        var owner = grant.Value.Child("owner").String("login") ?? throw new InvalidDataException("GitHub repository owner is missing.");
        var name = grant.Value.String("name") ?? throw new InvalidDataException("GitHub repository name is missing.");
        var branch = grant.Value.String("default_branch") ?? throw new InvalidDataException("GitHub default branch is missing.");
        var repository = new Repository(token, binding.RepositoryId, owner, name, branch, null, grant.Value.Boolean("private"));
        try
        {
            var branchData = await client.GetAsync<JsonElement>($"{repository.Api}/branches/{Uri.EscapeDataString(branch)}", token, ct);
            var head = branchData.Child("commit").String("sha");
            return repository with { HeadSha = IsSha(head) ? head : throw new InvalidDataException("The repository head SHA is invalid.") };
        }
        catch (GitHubApiException ex) when (ex.StatusCode is System.Net.HttpStatusCode.NotFound or System.Net.HttpStatusCode.Conflict)
        {
            // GitHub responds with 409 for empty repositories and can return 404 for their branch.
            // A repository with commits but a temporarily missing branch is retried, not cleared.
            try
            {
                var commits = await client.GetAsync<JsonElement>($"{repository.Api}/commits?per_page=1", token, ct);
                if (commits.GetArrayLength() == 0)
                    return repository;
            }
            catch (GitHubApiException empty) when (empty.StatusCode == System.Net.HttpStatusCode.Conflict)
            {
                return repository;
            }
            throw;
        }
    }

    private async Task<JsonElement?> FindGrantedRepositoryAsync(long repoId, string token, CancellationToken cancellationToken)
    {
        for (var page = 1; ; page++)
        {
            var data = await client.GetAsync<JsonElement>($"/installation/repositories?per_page={PageSize}&page={page}", token, cancellationToken);
            var repositories = data.Child("repositories");
            if (repositories.ValueKind != JsonValueKind.Array)
                throw new InvalidDataException("GitHub installation repositories are missing.");
            foreach (var repository in repositories.EnumerateArray())
            {
                if (repository.Number("id") == repoId)
                    return repository;
            }
            if (repositories.GetArrayLength() < PageSize)
                return null;
        }
    }

    public async Task<SourcePage> ReadCommitPageAsync(Repository repo, string headSha, string? previousHeadSha, int page, Func<IReadOnlyList<string>, CancellationToken, Task<HashSet<string>>> loadKnown, CancellationToken ct)
    {
        const int batch = 10;
        var (list, hasNext) = await ReadCommitRowsAsync(repo, headSha, previousHeadSha, page, batch, ct);
        var keys = list.EnumerateArray().Select(x => x.String("sha")).OfType<string>().ToArray();
        var known = await loadKnown(keys, ct);
        var items = new List<SourceItem>();
        foreach (var row in list.EnumerateArray())
        {
            var sha = row.String("sha");
            if (!IsSha(sha))
                throw new InvalidDataException("GitHub returned a commit without a valid SHA.");
            if (known.Contains(sha!))
                continue;
            var files = await ReadCommitFilesAsync(repo, sha!, ct);
            var data = row.Child("commit");
            var message = GitHubContentPolicy.Clean(data.String("message"));
            items.Add(SourceItem.Create("commit", sha!, new
            {
                sha,
                message,
                authorId = row.Child("author").Number("id"),
                authorLogin = GitHubContentPolicy.Clean(row.Child("author").String("login"), 256),
                commitDate = data.Child("committer").String("date"),
                authoredAt = data.Child("author").String("date"),
                parents = ArrayOf(row.Child("parents")).Select(x => x.String("sha")).Where(IsSha).ToArray(),
                url = $"{repo.Web}/commit/{sha}",
                files = files.Items.Select(ChangedFile),
                filesMayBeIncomplete = files.LimitReached,
                jiraKeys = GitHubContentPolicy.JiraKeys(message)
            }));
        }
        return new SourcePage(items, hasNext);
    }

    private async Task<(JsonElement Rows, bool HasNextPage)> ReadCommitRowsAsync(
        Repository repo, string headSha, string? previousHeadSha, int page, int batch, CancellationToken ct)
    {
        if (IsSha(previousHeadSha) && previousHeadSha != headSha)
        {
            try
            {
                // An ancestry comparison includes commits from a merged side branch even when
                // their commit times predate the previous default-branch head.
                var comparison = await client.GetAsync<JsonElement>(
                    $"{repo.Api}/compare/{previousHeadSha}...{headSha}?per_page={batch}&page={page}", repo.Token, ct);
                if (comparison.String("status") is "ahead" or "identical" &&
                    comparison.Child("commits") is { ValueKind: JsonValueKind.Array } delta &&
                    comparison.Number("total_commits") is long count)
                    return (delta, (long)page * batch < count);
            }
            catch (GitHubApiException ex) when (ex.StatusCode is System.Net.HttpStatusCode.NotFound or System.Net.HttpStatusCode.Conflict)
            {
                // Previous head may no longer be reachable after rewriting branch history.
            }
        }

        var history = await client.GetAsync<JsonElement>(
            $"{repo.Api}/commits?sha={headSha}&per_page={batch}&page={page}", repo.Token, ct);
        return (history, history.GetArrayLength() == batch);
    }

    private async Task<(IReadOnlyList<JsonElement> Items, bool LimitReached)> ReadCommitFilesAsync(Repository repo, string sha, CancellationToken ct)
    {
        const int max = 3_000; // GitHub caps the commit file list at 3,000.
        var result = new List<JsonElement>();
        for (var page = 1; result.Count < max; page++)
        {
            var data = await client.GetAsync<JsonElement>($"{repo.Api}/commits/{sha}?per_page={PageSize}&page={page}", repo.Token, ct);
            var files = data.Child("files");
            if (files.ValueKind != JsonValueKind.Array)
                throw new InvalidDataException("GitHub did not return a commit file list.");
            result.AddRange(files.EnumerateArray().Take(max - result.Count));
            if (files.GetArrayLength() < PageSize)
                return (result, false);
        }
        return (result, true);
    }

    private static object ChangedFile(JsonElement file) => new
    {
        path = GitHubContentPolicy.Clean(file.String("filename"), 1024),
        previousPath = GitHubContentPolicy.Clean(file.String("previous_filename"), 1024),
        status = file.String("status"),
        additions = file.Number("additions"),
        deletions = file.Number("deletions")
    };

    public async Task<SourcePage> ReadPullRequestPageAsync(Repository repo, int page, Func<IReadOnlyList<string>, CancellationToken, Task<Dictionary<string, string?>>> loadUpdates, CancellationToken ct)
    {
        const int batch = 10;
        var list = await client.GetAsync<JsonElement>($"{repo.Api}/pulls?state=all&sort=created&direction=asc&per_page={batch}&page={page}", repo.Token, ct);
        var keys = list.EnumerateArray().Select(x => x.Number("number")?.ToString(CultureInfo.InvariantCulture)).OfType<string>().ToArray();
        var knownUpdates = await loadUpdates(keys, ct);
        var items = new List<SourceItem>();
        foreach (var row in list.EnumerateArray())
        {
            var number = row.Number("number") ?? throw new InvalidDataException("GitHub returned a pull request without a number.");
            var key = number.ToString(CultureInfo.InvariantCulture);
            var updatedAt = row.String("updated_at");
            if (updatedAt is not null && knownUpdates.TryGetValue(key, out var known) && known == updatedAt)
                continue;

            var detail = await client.GetAsync<JsonElement>($"{repo.Api}/pulls/{key}", repo.Token, ct);
            var (files, fileLimitReached) = await ReadListAsync(repo, $"pulls/{key}/files", 3_000, ct);
            var (commits, commitLimitReached) = await ReadListAsync(repo, $"pulls/{key}/commits", 250, ct);
            var title = GitHubContentPolicy.Clean(detail.String("title"));
            var body = GitHubContentPolicy.Clean(detail.String("body"));
            var headRef = GitHubContentPolicy.Clean(detail.Child("head").String("ref"), 512);
            var fileCount = detail.Number("changed_files");
            var commitCount = detail.Number("commits");
            items.Add(SourceItem.Create("pull_request", key, new
            {
                number,
                title,
                body,
                state = detail.String("state"),
                draft = detail.Boolean("draft"),
                authorId = detail.Child("user").Number("id"),
                authorLogin = GitHubContentPolicy.Clean(detail.Child("user").String("login"), 256),
                headRef,
                baseRef = GitHubContentPolicy.Clean(detail.Child("base").String("ref"), 512),
                headSha = detail.Child("head").String("sha"),
                updatedAt = detail.String("updated_at"),
                createdAt = detail.String("created_at"),
                closedAt = detail.String("closed_at"),
                mergedAt = detail.String("merged_at"),
                mergedById = detail.Child("merged_by").Number("id"),
                mergeCommitSha = detail.String("merge_commit_sha"),
                url = $"{repo.Web}/pull/{key}",
                jiraKeys = GitHubContentPolicy.JiraKeys(title, body, headRef),
                files = files.Select(ChangedFile),
                filesMayBeIncomplete = fileCount is long expectedFiles ? expectedFiles > files.Count : fileLimitReached,
                commitShas = commits.Select(x => x.String("sha")).Where(IsSha).ToArray(),
                commitsMayBeIncomplete = commitCount is long expectedCommits ? expectedCommits > commits.Count : commitLimitReached
            }));
        }
        return new SourcePage(items, list.GetArrayLength() == batch);
    }

    private async Task<(IReadOnlyList<JsonElement> Items, bool LimitReached)> ReadListAsync(
        Repository repo, string suffix, int max, CancellationToken ct)
    {
        var result = new List<JsonElement>();
        for (var page = 1; result.Count < max; page++)
        {
            var response = await client.GetAsync<JsonElement>($"{repo.Api}/{suffix}?per_page={PageSize}&page={page}", repo.Token, ct);
            var remaining = max - result.Count;
            result.AddRange(response.EnumerateArray().Take(remaining));
            if (response.GetArrayLength() < PageSize)
                return (result, result.Count >= max);
        }
        return (result, true);
    }

    public async Task<CodeSnapshot> ReadCodeSnapshotAsync(
        Repository repo, IReadOnlyDictionary<string, string> previous, CancellationToken ct)
    {
        if (repo.HeadSha is null)
            return new CodeSnapshot([], 0, []);

        var commit = await client.GetAsync<JsonElement>($"{repo.Api}/git/commits/{repo.HeadSha}", repo.Token, ct);
        var treeSha = commit.Child("tree").String("sha");
        if (!IsSha(treeSha))
            throw new InvalidDataException("GitHub returned a commit without a valid tree SHA.");

        var files = await ReadTreeAsync(repo, treeSha!, ct);
        var prepared = new List<SourceItem>();
        var byteCount = 0L;
        var skipped = 0;
        var reasons = new HashSet<string>(StringComparer.Ordinal);
        foreach (var file in files.OrderBy(x => x.Path, StringComparer.Ordinal))
        {
            if (!GitHubContentPolicy.IsAllowedCodePath(file.Path))
            {
                skipped++;
                continue;
            }

            if (file.Size is not long fileSize || fileSize < 0 || fileSize > _options.MaxCodeFileBytes)
            {
                skipped++;
                reasons.Add("max_file_bytes");
                continue;
            }

            if (prepared.Count >= _options.MaxCodeFiles || byteCount + fileSize > _options.MaxCodeSnapshotBytes)
            {
                skipped++;
                reasons.Add("code_snapshot_limit");
                continue;
            }

            var entityId = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(file.Path))).ToLowerInvariant();
            string? code = null;
            if (previous.TryGetValue(entityId, out var stored))
            {
                using var document = JsonDocument.Parse(stored);
                if (document.RootElement.String("blobSha") == file.Sha)
                    code = document.RootElement.String("content");
            }

            if (code is null)
            {
                var blob = await client.GetAsync<JsonElement>($"{repo.Api}/git/blobs/{file.Sha}", repo.Token, ct);
                var encoded = blob.String("content");
                if (blob.String("encoding") != "base64" || encoded is null || encoded.Length > _options.MaxCodeFileBytes * 2)
                    throw new InvalidDataException("GitHub did not return the expected bounded blob data.");
                byte[] bytes;
                try { bytes = Convert.FromBase64String(encoded); }
                catch (FormatException)
                {
                    throw new InvalidDataException("GitHub returned an invalid encoded blob.");
                }
                if (bytes.Length != fileSize)
                    throw new InvalidDataException("GitHub returned a blob that differs from the selected tree.");
                if (!GitHubContentPolicy.TryReadText(bytes, out var decoded))
                {
                    skipped++;
                    reasons.Add("unsupported_blob");
                    continue;
                }
                code = GitHubContentPolicy.Clean(decoded, _options.MaxCodeFileBytes)!;
            }

            byteCount += fileSize;
            var lines = CountLines(code);
            prepared.Add(SourceItem.Create("file", entityId, new
            {
                path = file.Path,
                blobSha = file.Sha,
                headSha = repo.HeadSha,
                startLine = 1,
                endLine = lines,
                content = code,
                url = $"{repo.Web}/blob/{repo.HeadSha}/{string.Join("/", file.Path.Split('/').Select(Uri.EscapeDataString))}#L1-L{lines}"
            }));
        }

        return new CodeSnapshot(prepared, skipped, reasons.Order(StringComparer.Ordinal).ToArray());
    }

    private async Task<IReadOnlyList<TreeFile>> ReadTreeAsync(Repository repo, string treeSha, CancellationToken ct)
    {
        var recursive = await client.GetAsync<JsonElement>($"{repo.Api}/git/trees/{treeSha}?recursive=1", repo.Token, ct);
        var result = new List<TreeFile>();
        if (!recursive.Boolean("truncated"))
        {
            var items = recursive.Child("tree");
            EnsureTreeLimit(items.GetArrayLength());
            AppendTreeFiles(items, "", result);
            return result;
        }

        var pending = new Stack<(string Sha, string Prefix)>();
        pending.Push((treeSha, ""));
        var explored = 0;
        while (pending.TryPop(out var node))
        {
            var data = await client.GetAsync<JsonElement>($"{repo.Api}/git/trees/{node.Sha}", repo.Token, ct);
            if (data.Boolean("truncated"))
                throw new InvalidDataException("GitHub returned a truncated non-recursive tree.");
            var items = data.Child("tree");
            explored += items.GetArrayLength();
            EnsureTreeLimit(explored);
            AppendTreeFiles(items, node.Prefix, result);
            foreach (var child in items.EnumerateArray())
            {
                if (child.String("type") == "tree" && child.String("path") is { } path && IsSha(child.String("sha")))
                    pending.Push((child.String("sha")!, node.Prefix + path + "/"));
            }
        }
        return result;
    }

    private void EnsureTreeLimit(int entries)
    {
        if (entries > _options.MaxTreeEntries)
            throw new InvalidDataException("The repository tree exceeded GitHubSync:MaxTreeEntries.");
    }

    private static void AppendTreeFiles(JsonElement array, string prefix, List<TreeFile> result)
    {
        foreach (var item in array.EnumerateArray())
        {
            var sha = item.String("sha");
            if (item.String("type") == "blob" && item.String("mode") is "100644" or "100755"
                && item.String("path") is { } path && IsSha(sha))
                result.Add(new TreeFile(prefix + path, sha!, item.Number("size")));
        }
    }

    private sealed record TreeFile(string Path, string Sha, long? Size);
    private static JsonElement[] ArrayOf(JsonElement value) => value.ValueKind == JsonValueKind.Array ? value.EnumerateArray().ToArray() : [];
    private static int CountLines(string value) => Math.Max(1, value.Count(c => c == '\n') + (value.EndsWith('\n') ? 0 : 1));
    private static bool IsSha(string? value) => value is { Length: 40 or 64 } && value.All(Uri.IsHexDigit);
}

internal static class GitHubSyncJson
{
    public static JsonElement Child(this JsonElement source, string key)
        => source.ValueKind == JsonValueKind.Object && source.TryGetProperty(key, out var child) ? child : default;
    public static string? String(this JsonElement source, string key)
        => source.Child(key) is { ValueKind: JsonValueKind.String } value ? value.GetString() : null;
    public static bool Boolean(this JsonElement source, string key)
        => source.Child(key).ValueKind == JsonValueKind.True;
    public static long? Number(this JsonElement source, string key)
        => source.Child(key) is { ValueKind: JsonValueKind.Number } value && value.TryGetInt64(out var i) ? i : null;
}
