using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Client.Queries.GetClientById
{
    public class GetClientByIdQuery : IRequest<ClientResponseDTO>
    {
        public string ClientId { get; set; } = null!;
    }
}
