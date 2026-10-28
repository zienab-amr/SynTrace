using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Features.Employee.Queries.GetAllEmployees;
using SynTrace.Application.Features.Role.Commands.CreateRole;
using SynTrace.Application.Features.Role.Commands.DeleteRole;
using SynTrace.Application.Features.Role.Commands.UpdateRole;
using SynTrace.Application.Features.Role.Queries.GetAllRoles;
using SynTrace.Application.Features.Role.Queries.GetRoleByName;

namespace SynTrace_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class RoleController : ControllerBase
    {
        private readonly IMediator _mediator;
        public RoleController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpPost("create-role")]
        public async Task<IActionResult> Create(CreateRoleCommand command)
        {
            await _mediator.Send(command);

            return Ok("Role created successfully");
        }

        [HttpPut("update-role")]
        public async Task<IActionResult> Update(UpdateRoleCommand command)
        {
            await _mediator.Send(command);

            return Ok("Role updated successfully");
        }

        [HttpDelete("delete-role")]
        public async Task<IActionResult> Delete(DeleteRoleCommand command)
        {
            await _mediator.Send(command);

            return Ok("Role deleted successfully");
        }

        [HttpGet("get-all-roles")]
        public async Task<IActionResult> GetAllRoles()
        {
            var roles = await _mediator.Send(new GetAllRolesQuery());

            return Ok(roles);
        }

        [HttpGet("get-role-by-name")]
        public async Task<IActionResult> GetRoleByName([FromQuery] GetRoleByNameQuery query)
        {
            var role = await _mediator.Send(query);

            return Ok(role);
        }
    }
}
