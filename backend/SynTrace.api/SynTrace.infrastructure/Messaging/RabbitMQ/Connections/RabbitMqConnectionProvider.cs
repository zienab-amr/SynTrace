using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Connections
{
    public sealed class RabbitMqConnectionProvider : IAsyncDisposable
    {
        private readonly ConnectionFactory _connectionFactory;
        private readonly SemaphoreSlim _lock = new(1, 1);

        private IConnection? _connection;

        public RabbitMqConnectionProvider(
            IOptions<RabbitMqOptions> options)
        {
            var settings = options.Value;

            _connectionFactory = new ConnectionFactory
            {
                HostName = settings.HostName,
                Port = settings.Port,
                VirtualHost = settings.VirtualHost,
                UserName = settings.UserName,
                Password = settings.Password,
                ClientProvidedName = settings.ClientProvidedName,

                AutomaticRecoveryEnabled = true,
                NetworkRecoveryInterval = TimeSpan.FromSeconds(10)
            };
        }

        public async Task<IConnection> GetConnectionAsync(
            CancellationToken cancellationToken = default)
        {
            await _lock.WaitAsync(cancellationToken);

            try
            {
                if (_connection is not null)
                    return _connection;

                _connection = await _connectionFactory
                    .CreateConnectionAsync(cancellationToken);

                return _connection;
            }
            finally
            {
                _lock.Release();
            }
        }

        public async ValueTask DisposeAsync()
        {
            await _lock.WaitAsync();

            try
            {
                if (_connection is not null)
                {
                    await _connection.DisposeAsync();
                    _connection = null;
                }
            }
            finally
            {
                _lock.Release();
                _lock.Dispose();
            }
        }
    }
}
