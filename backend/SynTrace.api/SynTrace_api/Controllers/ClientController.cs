using Microsoft.AspNetCore.Authorization;
using SynTrace.Infrastructure.Integrations.GitHub;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Features.Client.Commands.CreateClient;
using SynTrace.Application.Features.Client.Commands.UpdateClient;
using SynTrace.Application.Features.Client.Queries.GetAllClients;
using SynTrace.Application.Features.Client.Queries.GetClientById;

namespace SynTrace.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class ClientController : ControllerBase
    {
        private readonly IMediator _mediator;
        public ClientController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
        [HttpPost]
        public async Task<IActionResult> Create(CreateClientCommand command)
        {
            var client = await _mediator.Send(command);

            return Ok(client);
        }

        [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
        [HttpPut("{clientId}")]
        public async Task<IActionResult> Update(string clientId, UpdateClientCommand command)
        {
            if (command.ClientId is not null && !string.Equals(command.ClientId, clientId, StringComparison.Ordinal))
                return BadRequest(new { message = "The client ID in the request must match the route." });
            command.ClientId = clientId;
            var client = await _mediator.Send(command);

            return Ok(client);
        }

        [HttpGet("{clientId}")]
        public async Task<IActionResult> Get(string clientId)
        {
            var client = await _mediator.Send(new GetClientByIdQuery { ClientId = clientId });

            return Ok(client);
        }

        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] GetAllClientsQuery query)
        {
            var clients = await _mediator.Send(query);

            return Ok(clients);
        }
    }
}
