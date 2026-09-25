using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.DTOs.Responses
{
    public class TokenResultDTO
    {
        public string AccessToken { get; set; }
        public DateTime AccessTokenExpiration { get; set; }

        public string RefreshToken { get; set; }
        public DateTime RefreshTokenExpiration { get; set; }
    }
}
