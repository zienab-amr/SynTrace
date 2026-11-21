using MediatR;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Exceptions;

namespace SynTrace.Application.Features.Client.Commands.UpdateClient
{
    public class UpdateClientCommandHandler : IRequestHandler<UpdateClientCommand, ClientResponseDTO>
    {
        private readonly IClientService _clientService;

        public UpdateClientCommandHandler(IClientService clientService)
        {
            _clientService = clientService;
        }
        public async Task<ClientResponseDTO> Handle(UpdateClientCommand request, CancellationToken cancellationToken)
        {
            var clientId = request.ClientId;
            if (string.IsNullOrWhiteSpace(clientId))
                throw new RequestFailureException(400, "Client ID is required.");

            var clientRequest = new ClientRequestDTO
            {
                ClientName = request.ClientName,
                PhoneNumber = request.PhoneNumber,
                Email = request.Email,
                Status = request.Status
            };

            return await _clientService.UpdateClientAsync(clientId, clientRequest, cancellationToken);
        }
    }
}
