using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity
{
    public class RegisterService : IRegisterService
    {
        private readonly SynTraceDbContext _context;
        private readonly UserManager<Employee> _userManager;
        private readonly IOTPService _otpService;
        public RegisterService(SynTraceDbContext context, UserManager<Employee> userManager, IOTPService otpService)
        {
            _context = context;
            _userManager = userManager;
            _otpService = otpService;
        }
        public async Task<RegisterResponseDTO> CreateFirstEmployeeAsync(RegisterRequestDTO requestDto)
        {
            if (requestDto == null)
                throw new ArgumentNullException(nameof(requestDto));

            var existingEmail = await _userManager.FindByEmailAsync(requestDto.Email);

            if(existingEmail != null)
                throw new InvalidOperationException("Email already exists.");

            if (!_otpService.IsEmailVerified(requestDto.Email))
            {
                throw new InvalidOperationException(
                    "Email must be verified before registration.");
            }

            var company = new Company
            {
                CompanyId = Guid.NewGuid().ToString(),
                CompanyName = requestDto.CompanyName
            };

            _context.Companies.Add(company);

            var employee = new Employee
            {
                FirstName = requestDto.FirstName,
                LastName = requestDto.LastName,
                Email = requestDto.Email,
                UserName = requestDto.Email,
                PhoneNumber = requestDto.PhoneNumber,
                Company = company,
            };

            var result = await _userManager.CreateAsync(employee, requestDto.Password);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description)));
            }

            var roleResult = await _userManager.AddToRoleAsync(employee, "Admin");

            if (!roleResult.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", roleResult.Errors.Select(e => e.Description)));
            }

            _otpService.RemoveEmailVerification(requestDto.Email);

            var responseDto = new RegisterResponseDTO
            {
                EmployeeId = employee.Id,
                CompanyId = company.CompanyId,
                Email = employee.Email
            };
            return responseDto;

        }

    }
}
