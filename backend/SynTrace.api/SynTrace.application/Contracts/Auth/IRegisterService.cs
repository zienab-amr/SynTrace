using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;

namespace SynTrace.Domain.Interfaces
{
    public interface IRegisterService
    {
        public Task<RegisterResponseDTO> CreateFirstEmployeeAsync(RegisterRequestDTO requestDto);
    }
}
