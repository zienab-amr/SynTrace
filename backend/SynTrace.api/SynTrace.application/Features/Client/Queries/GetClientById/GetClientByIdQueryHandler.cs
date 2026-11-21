using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Features.Client.Commands.UpdateClient;

namespace SynTrace.Application.Features.Client.Queries.GetClientById
{
    public class GetClientByIdQueryHandler : IRequestHandler<GetClientByIdQuery, ClientResponseDTO>
    {
        private readonly IClientService _clientService;
        public GetClientByIdQueryHandler(IClientService clientService)
        {
            _clientService = clientService;
        }
        public async Task<ClientResponseDTO> Handle(GetClientByIdQuery request, CancellationToken cancellationToken)
        {
            return await _clientService.GetClientByIdAsync(request.ClientId, cancellationToken);
        }
    }
}
