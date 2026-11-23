using SynTrace.Application.Exceptions;
using SynTrace.Application.Services;

internal static class PendingAssistantTurnChecks
{
    public static async Task RunAsync()
    {
        var store = new PendingAssistantTurnStore();
        var root = Guid.NewGuid().ToString();
        var pending = store.Create("company-A", "employee-A", root,
            "conversation-A", newConversation: false, editedMessageId: null, question: "status SYNTECH-1",
            quotedExcerpts: ["Sprint 14 delay"]);
        Assert(pending.QuotedExcerpts.SequenceEqual(["Sprint 14 delay"]),
            "Quoted text selected on the original pending ask must be retained.");

        Assert(ReferenceEquals(store.Find("company-A", "employee-A", root), pending), "Owner must see pending turn");
        Assert(store.Find("company-B", "employee-A", root) is null, "Other company must not see turn");
        Assert(store.Find("company-A", "employee-B", root) is null, "Other employee must not see turn");

        try
        {
            store.Create("company-A", "employee-A", root,
                "conversation-A", false, null, "duplicate");
            throw new Exception("Duplicate pending root must fail.");
        }
        catch (RequestFailureException expected) when (expected.StatusCode == 409)
        {
            // Expected idempotency/conflict signal.
        }

        await pending.Gate.WaitAsync();
        try
        {
            pending.ActiveCancellation.Cancel();
            pending.Questions.Add("ومين عليها؟");
            pending.QuotedExcerpts.Add("Assigned to Fatma");
            Assert(pending.QuotedExcerpts.SequenceEqual(["Sprint 14 delay", "Assigned to Fatma"]),
                "A subsequent append must retain original and later quoted selections in order.");
            pending.Revision++;
            Assert(pending.ActiveCancellation.IsCancellationRequested, "Previous request must be cancelled");
            Assert(pending.Questions.SequenceEqual(new[] { "status SYNTECH-1", "ومين عليها؟" }),
                "Pending bubbles must retain original order");
            pending.Completed = true;
        }
        finally { pending.Gate.Release(); }
        Assert(store.Find("company-A", "employee-A", root)?.Completed == true,
            "Completed roots remain briefly to resolve late appends as normal questions");
    }

    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
}
