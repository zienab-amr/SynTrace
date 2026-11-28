namespace SynTrace.Application.Contracts.Meetings;

public static class MeetingPermission
{
    public const string ClaimType = "syntrace:meeting-permission";
    public const string ReadApproved = "Meetings.ReadApproved";
    public const string UseAgent = "Meetings.UseAgent";
    public const string Approve = "Meetings.Approve";
    public const string PublishJiraTasks = "Meetings.PublishJiraTasks";
    public const string Create = "Meetings.Create";
    public const string ReadPending = "Meetings.ReadPending";
    public const string Edit = "Meetings.Edit";
    public const string Delete = "Meetings.Delete";
    public const string ExportPdf = "Meetings.ExportPdf";
    public const string ManageLiveSessions = "Meetings.ManageLiveSessions";

    public static IReadOnlyList<string> All { get; } = Array.AsReadOnly(new[]
    {
        ReadApproved, UseAgent, Approve, PublishJiraTasks, Create, ReadPending,
        Edit, Delete, ExportPdf, ManageLiveSessions
    });
}

public sealed record MeetingAssistantPermissions(
    bool CanReadApprovedMeetings,
    bool CanUseMeetingAgent,
    bool CanApproveMeeting,
    bool CanPublishJiraTasks)
{
    public static MeetingAssistantPermissions From(IReadOnlySet<string> grants) => new(
        grants.Contains(MeetingPermission.ReadApproved),
        grants.Contains(MeetingPermission.UseAgent),
        grants.Contains(MeetingPermission.Approve),
        grants.Contains(MeetingPermission.PublishJiraTasks));
}

public interface IMeetingPermissionService
{
    Task<IReadOnlySet<string>> GetForEmployeeAsync(string companyId, string employeeId, CancellationToken ct);
    Task<IReadOnlyList<string>> GetForRoleAsync(string roleId, CancellationToken ct);
    Task<IReadOnlyList<string>> ReplaceForRoleAsync(string roleId, IReadOnlyList<string> permissions, CancellationToken ct);
}
