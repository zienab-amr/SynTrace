using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Commands.ChangeEmployee
{
    public class ChangeEmployeeRoleCommandHandler : IRequestHandler<ChangeEmployeeRoleCommand>
    {
        private readonly IEmployeeRepository _repository;
        private readonly UserManager<SynTrace.Domain.Entities.Employee> _userManager;
        public ChangeEmployeeRoleCommandHandler(IEmployeeRepository repository, UserManager<SynTrace.Domain.Entities.Employee> userManager)
        {
            _repository = repository;
            _userManager = userManager;
        }
        public async Task Handle(ChangeEmployeeRoleCommand request, CancellationToken cancellationToken)
        {
            var employee = await _repository.GetEmployeeByIdAsync(request.EmployeeId);

            if(employee == null)
                throw new Exception("Sorry, Employee not found");

            var currentRoles = await _userManager.GetRolesAsync(employee);

            if (!currentRoles.Any())
                throw new Exception("Employee has no role");

            var oldRole = currentRoles.First();


            var result = await _repository.ChangeEmployeeRole(employee, oldRole, request.NewRole);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description))
                );
            }

        }
    }
}
