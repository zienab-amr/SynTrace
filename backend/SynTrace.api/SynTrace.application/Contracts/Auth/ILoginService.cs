using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Contracts.Auth
{
    public interface ILoginService
    {
        public Task<TokenResultDTO> GetEmployeeByEmail(LoginRequestDTO requestDTO);

    }
}
