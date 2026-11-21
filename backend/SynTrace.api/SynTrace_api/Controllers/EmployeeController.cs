using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Features.Employee.Commands.ChangeEmployee;
using SynTrace.Application.Features.Employee.Commands.CreateEmployee;
using SynTrace.Application.Features.Employee.Commands.DeleteEmployee;
using SynTrace.Application.Features.Employee.Commands.UpdateEmployee;
using SynTrace.Application.Features.Employee.Queries.GetAllEmployees;
using SynTrace.Application.Features.Employee.Queries.GetEmployeeById;
using SynTrace.Application.Features.Employee.Queries.GetEmployeesByName;
using SynTrace.Application.Features.Employee.Queries.GetEmployeesByRole;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Integrations.GitHub;

namespace SynTrace_api.Controllers;

[Authorize]
[Route("api/[controller]")]
[ApiController]
public sealed class EmployeeController(IMediator mediator, IEmployeeRepository directory, ICurrentEmployee actor) : ControllerBase
{
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpPost("create-employee")]
    public async Task<ActionResult<EmployeeResponseDTO>> Create(CreateEmployeeCommand command, CancellationToken ct) =>
        Ok(await ResponseAsync(await mediator.Send(command, ct)));

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpPut("update-employee")]
    public async Task<ActionResult<EmployeeResponseDTO>> Update(UpdateEmployeeCommand command, CancellationToken ct) =>
        Ok(await ResponseAsync(await mediator.Send(command, ct)));

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpDelete("delete-employee")]
    public async Task<IActionResult> Delete(DeleteEmployeeCommand command, CancellationToken ct) =>
        Ok(await mediator.Send(command, ct));

    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    [HttpPut("change-role")]
    public async Task<IActionResult> ChangeRole(ChangeEmployeeRoleCommand command, CancellationToken ct)
    {
        await mediator.Send(command, ct);
        return Ok();
    }

    [HttpGet("all-employee")]
    public async Task<ActionResult<EmployeeResponseDTO[]>> AllEmployee(CancellationToken ct) =>
        Ok(await ResponsesAsync(await mediator.Send(new GetAllEmployeesQuery(), ct)));

    [HttpGet("employee-by-id")]
    public async Task<ActionResult<EmployeeResponseDTO>> GetById([FromQuery] GetEmployeeByIdQuery query, CancellationToken ct) =>
        Ok(await ResponseAsync(await mediator.Send(query, ct)));

    [HttpGet("employees-by-name")]
    public async Task<ActionResult<EmployeeResponseDTO[]>> GetByName([FromQuery] GetEmployeesByNameQuery query, CancellationToken ct) =>
        Ok(await ResponsesAsync(await mediator.Send(query, ct)));

    [HttpGet("employees-by-role")]
    public async Task<ActionResult<EmployeeResponseDTO[]>> GetByRole([FromQuery] GetEmployeesByRoleQuery query, CancellationToken ct) =>
        Ok(await ResponsesAsync(await mediator.Send(query, ct)));

    [HttpGet("me")]
    public async Task<ActionResult<EmployeeResponseDTO>> Me(CancellationToken ct) =>
        Ok(await ResponseAsync(await mediator.Send(new GetEmployeeByIdQuery { EmployeeId = actor.EmployeeId }, ct)));

    [HttpPut("me")]
    public async Task<ActionResult<EmployeeResponseDTO>> UpdateMe(UpdateEmployeeProfileRequest request, CancellationToken ct) =>
        Ok(await ResponseAsync(await mediator.Send(new UpdateEmployeeCommand
        {
            EmployeeId = actor.EmployeeId,
            FirstName = request.FirstName,
            LastName = request.LastName,
            PhoneNumber = request.PhoneNumber
        }, ct)));

    private async Task<EmployeeResponseDTO> ResponseAsync(Employee employee) =>
        (await ResponsesAsync([employee]))[0];

    private async Task<EmployeeResponseDTO[]> ResponsesAsync(ICollection<Employee> employees)
    {
        if (employees.Count == 0)
            return [];

        var roles = await directory.GetRolesForEmployeesAsync(employees.Select(x => x.Id).ToArray());
        return employees.Select(employee => new EmployeeResponseDTO(
            employee.Id, employee.FirstName, employee.LastName, employee.Email, employee.PhoneNumber,
            employee.CompanyId, roles[employee.Id].Select(role => new EmployeeRoleResponseDTO(role.Id, role.Name)).ToArray()))
            .ToArray();
    }
}
