using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Commands.CreateEmployee
{
    public class CreateEmployeeCommandHandler : IRequestHandler<CreateEmployeeCommand, SynTrace.Domain.Entities.Employee>
    {
        private readonly IEmployeeRepository _repository;
        private readonly IRoleService _roleService;
        private readonly ICurrentTenant _currentTenant;
        public CreateEmployeeCommandHandler(IEmployeeRepository repository, IRoleService roleService, ICurrentTenant currentTenant)
        {
            _repository = repository;
            _roleService = roleService;
            _currentTenant = currentTenant;
        }

        public async Task<SynTrace.Domain.Entities.Employee> Handle(CreateEmployeeCommand request, CancellationToken cancellationToken)
        {
            if (request == null)
                throw new Exception("error , please try again");
            var check = await _repository.GetEmployeeByEmailAsync(request.Email);

            if (check != null)
                throw new Exception("Sorry, this email already exist");

            var employee = new SynTrace.Domain.Entities.Employee
            {
                FirstName = request.FirstName,
                LastName = request.LastName,
                Email = request.Email,
                UserName = request.Email,
                PhoneNumber = request.PhoneNumber,
                CompanyId = _currentTenant.CompanyId
            };
            var result = await _repository.CreateEmployeeAsync(employee, request.Password);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description)));
            }

            var roleResult = await _roleService.AssignRoleAsync(employee, request.Role);
            if (!roleResult.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", roleResult.Errors.Select(e => e.Description)));
            }

            return employee;
        }
    }
}
