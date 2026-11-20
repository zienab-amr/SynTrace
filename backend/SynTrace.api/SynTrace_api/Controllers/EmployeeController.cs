using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Features.Employee.Commands.ChangeEmployee;
using SynTrace.Application.Features.Employee.Commands.CreateEmployee;
using SynTrace.Application.Features.Employee.Commands.DeleteEmployee;
using SynTrace.Application.Features.Employee.Commands.UpdateEmployee;
using SynTrace.Application.Features.Employee.Queries.GetEmployeeById;
using SynTrace.Application.Features.Employee.Queries.GetEmployeesByName;
using SynTrace.Application.Features.Employee.Queries.GetEmployeesByRole;

namespace SynTrace_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class EmployeeController : ControllerBase
    {
        private readonly IMediator _mediator;
        public EmployeeController(IMediator mediator)
        {
            _mediator = mediator;
        }
        [HttpPost("create-employee")]
        public async Task<IActionResult> Create(CreateEmployeeCommand command)
        {
            var employee = await _mediator.Send(command);

            return Ok(employee);
        }

        [HttpPut("update-employee")] 
        public async Task<IActionResult> Update(UpdateEmployeeCommand command)
        {
            var employee = await _mediator.Send(command);

            return Ok(employee);
        }

        [HttpDelete("delete-employee")]
        public async Task<IActionResult> Delete(DeleteEmployeeCommand command)
        {
            var delete = await _mediator.Send(command);
            return Ok(delete);
        }

        [HttpPut("change-role")]
        public async Task<IActionResult> ChangeRole(ChangeEmployeeRoleCommand command)
        {
            await _mediator.Send(command);
            return Ok();
        }

        [HttpGet("all-employee")]
        public async Task<IActionResult> AllEmployee([FromQuery] GetEmployeesByRoleQuery query)
        {
            var employees = await _mediator.Send(query);

            return Ok(employees);
        }

        [HttpGet("employee-by-id")]
        public async Task<IActionResult> GetById([FromQuery] GetEmployeeByIdQuery query)
        {
            var employee = await _mediator.Send(query);
            return Ok(employee);
        }

        [HttpGet("employees-by-name")]
        public async Task<IActionResult> GetByName([FromQuery] GetEmployeesByNameQuery query)
        {
            var employees = await _mediator.Send(query);
            return Ok(employees);
        }

        [HttpGet("employees-by-role")]
        public async Task<IActionResult> GetByRole([FromQuery] GetEmployeesByRoleQuery query)
        {
            var employees = await _mediator.Send(query);
            return Ok(employees);
        }
    }
}
