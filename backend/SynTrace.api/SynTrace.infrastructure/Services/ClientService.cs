using SynTrace.Application.Exceptions;
using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Repositories;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;

namespace SynTrace.Infrastructure.Services
{
    public class ClientService : IClientService
    {
        private readonly IClientRepository _clientRepository;
        public ClientService(
            IClientRepository clientRepository
            )
        {
            _clientRepository = clientRepository;
        }
        public async Task<List<ClientResponseDTO>> GetAllClientsAsync(CancellationToken cancellationToken)
        {
            var clients = await _clientRepository.GetAllClientsAsync(cancellationToken);

            return clients.Select(client => new ClientResponseDTO
            {
                ClientId = client.ClientId,
                ClientName = client.ClientName,
                PhoneNumber = client.PhoneNumber,
                Email = client.Email,
                Status = client.Status
            }).ToList();
        }
        public async Task<ClientResponseDTO> GetClientByIdAsync(string clientId, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(clientId))
                throw new RequestFailureException(400, "Client ID cannot be empty.");

            var client = await _clientRepository.GetClientById(clientId, cancellationToken);

            if (client == null)
                throw new KeyNotFoundException("Client does not exist.");

            return new ClientResponseDTO
            {
                ClientId = client.ClientId,
                ClientName = client.ClientName,
                PhoneNumber = client.PhoneNumber,
                Email = client.Email,
                Status = client.Status
            };
        }
        public async Task<ClientResponseDTO> CreateClientAsync(ClientRequestDTO request, CancellationToken cancellationToken)
        {
            var client = await _clientRepository.CreateClientAsync(request, cancellationToken);

            return new ClientResponseDTO
            {
                ClientId = client.ClientId,
                ClientName = client.ClientName,
                PhoneNumber = client.PhoneNumber,
                Email = client.Email,
                Status = client.Status
            };
        }
        public async Task<ClientResponseDTO> UpdateClientAsync(string clientId, ClientRequestDTO request, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(clientId))
                throw new RequestFailureException(400, "Client ID cannot be empty.");

            var client =  await _clientRepository.UpdateClientAsync(clientId, request, cancellationToken);

            return new ClientResponseDTO
            {
                ClientId = client.ClientId,
                ClientName = client.ClientName,
                PhoneNumber = client.PhoneNumber,
                Email = client.Email,
                Status = client.Status
            };
        }

    }
}
