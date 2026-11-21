using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;

namespace SynTrace.Application.Contracts
{
    public interface IClientService
    {
        public Task<List<ClientResponseDTO>> GetAllClientsAsync(CancellationToken cancellationToken);
        public Task<ClientResponseDTO> GetClientByIdAsync(string clientId, CancellationToken cancellationToken);
        public Task<ClientResponseDTO> CreateClientAsync(ClientRequestDTO request, CancellationToken cancellationToken);
        public Task<ClientResponseDTO> UpdateClientAsync(string clientId, ClientRequestDTO request, CancellationToken cancellationToken);

    }
}
