using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.DTOs;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity
{
    public class RegisterService
    {
        private readonly SynTraceDbContext _context;
        private readonly UserManager<Employee> _userManager;
        private readonly OTPService _otpService;
        public RegisterService(SynTraceDbContext context, UserManager<Employee> userManager, OTPService otpService)
        {
            _context = context;
            _userManager = userManager;
            _otpService = otpService;
        }
        public async Task<Employee> CreateFirstEmployeeAsync(RegisterRequestDTO requestDto)
        {
            if (requestDto == null)
                throw new ArgumentNullException(nameof(requestDto));

            var existingEmail = await _userManager.FindByEmailAsync(requestDto.Email);

            if(existingEmail != null)
                throw new InvalidOperationException("Email already exists.");


            var valid = _otpService.ValidateOTP(new VerifyOTPRequestDTO
            {
                Email = requestDto.Email,
                OTP = requestDto.OTP
            });

            if(!valid)
                throw new InvalidOperationException("Invalid OTP.");

            var company = new Company
            {
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

            await _userManager.AddToRoleAsync(employee, "Admin");

            return employee;

        }



    }
}
