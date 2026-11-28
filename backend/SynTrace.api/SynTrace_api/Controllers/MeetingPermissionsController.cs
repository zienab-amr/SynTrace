using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Infrastructure.Integrations.GitHub;

namespace SynTrace.Api.Controllers;

[ApiController]
[Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
[Route("api/roles/{roleId}/meeting-permissions")]
public sealed class MeetingPermissionsController(IMeetingPermissionService permissions) : ControllerBase
{
    public sealed record ReplacePermissionsRequest(IReadOnlyList<string> Permissions);

    [HttpGet]
    public async Task<IActionResult> Get(string roleId, CancellationToken ct) =>
        Ok(new { permissions = await permissions.GetForRoleAsync(roleId, ct), available = MeetingPermission.All });

    [HttpPut]
    public async Task<IActionResult> Put(string roleId, ReplacePermissionsRequest request, CancellationToken ct)
    {
        if (request.Permissions is null) return BadRequest();
        return Ok(new { permissions = await permissions.ReplaceForRoleAsync(roleId, request.Permissions, ct) });
    }
}
