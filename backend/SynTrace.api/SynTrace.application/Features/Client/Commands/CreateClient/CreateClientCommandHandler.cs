using MediatR;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Client.Commands.CreateClient
{
    public class CreateClientCommandHandler
        : IRequestHandler<CreateClientCommand, ClientResponseDTO>
    {
        private readonly IClientService _clientService;

        public CreateClientCommandHandler(IClientService clientService)
        {
            _clientService = clientService;
        }

        public async Task<ClientResponseDTO> Handle(CreateClientCommand request, CancellationToken cancellationToken)
        {
            var clientRequest = new ClientRequestDTO
            {
                ClientName = request.ClientName,
                PhoneNumber = request.PhoneNumber,
                Email = request.Email,
                Status = request.Status
            };

            return await _clientService.CreateClientAsync(clientRequest, cancellationToken);
        }
    }
}