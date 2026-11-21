using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Client.Queries.GetAllClients
{
    public class GetAllClientsQueryHandler : IRequestHandler<GetAllClientsQuery, List<ClientResponseDTO>>
    {
        private readonly IClientService _clientService;
        public GetAllClientsQueryHandler(IClientService clientService)
        {
            _clientService = clientService;
        }
        public async Task<List<ClientResponseDTO>> Handle(GetAllClientsQuery request, CancellationToken cancellationToken)
        {
            return await _clientService.GetAllClientsAsync(cancellationToken);


        }
    }
}
