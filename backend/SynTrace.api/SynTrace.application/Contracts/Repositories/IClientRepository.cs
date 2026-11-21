using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Domain.Entities;

namespace SynTrace.Application.Contracts.Repositories
{
    public interface IClientRepository
    {
        public Task<List<Client>> GetAllClientsAsync(CancellationToken cancellationToken);
        public Task<Client?> GetClientById(string clientId, CancellationToken cancellationToken);
        public Task<Client> CreateClientAsync(ClientRequestDTO request, CancellationToken cancellationToken);
        public Task<Client> UpdateClientAsync(string clientId, ClientRequestDTO request, CancellationToken cancellationToken);

    }
}
