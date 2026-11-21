using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Repositories;
using SynTrace.Application.DTOs.Requests;

namespace SynTrace.Infrastructure.Repositories
{
    public class ClientRepository : IClientRepository
    {
        private readonly SynTraceDbContext _db;
        private readonly ICurrentTenant _currentTenant;

        public ClientRepository(
            SynTraceDbContext db,
            ICurrentTenant currentTenant)
        {
            _db = db;
            _currentTenant = currentTenant;
        }

        public async Task<List<Client>> GetAllClientsAsync(CancellationToken cancellationToken)
        {
            return await _db.Clients.ToListAsync(cancellationToken);
        }

        public async Task<Client?> GetClientById(string clientId, CancellationToken cancellationToken)
        {
            return await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, cancellationToken);
        }

        public async Task<Client> CreateClientAsync(ClientRequestDTO request, CancellationToken cancellationToken)
        {
            var client = new Client
            {
                ClientName = request.ClientName,
                PhoneNumber = request.PhoneNumber,
                Email = request.Email,
                Status = request.Status,
                CompanyId = _currentTenant.CompanyId
            };

            await _db.Clients.AddAsync(client, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);

            return client;
        }

        public async Task<Client> UpdateClientAsync(string clientId, ClientRequestDTO request, CancellationToken cancellationToken)
        {
            var client = await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, cancellationToken);

            if (client == null)
                throw new KeyNotFoundException("Client does not exist.");

            client.ClientName = request.ClientName;
            client.PhoneNumber = request.PhoneNumber;
            client.Email = request.Email;
            client.Status = request.Status;

            await _db.SaveChangesAsync(cancellationToken);

            return client;
        }
    }
}