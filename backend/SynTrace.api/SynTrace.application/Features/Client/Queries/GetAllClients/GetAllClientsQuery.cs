using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Client.Queries.GetAllClients
{
    public class GetAllClientsQuery : IRequest<List<ClientResponseDTO>>
    {
    }
}
