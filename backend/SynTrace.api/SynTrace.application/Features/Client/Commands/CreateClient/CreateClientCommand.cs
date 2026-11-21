using System.ComponentModel.DataAnnotations;
using MediatR;
using SynTrace.Domain.Enums;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Client.Commands.CreateClient
{
    public class CreateClientCommand : IRequest<ClientResponseDTO>
    {
        [Required, StringLength(200)]
        public string ClientName { get; set; } = null!;
        [StringLength(50)]
        public string? PhoneNumber { get; set; }
        [EmailAddress, StringLength(254)]
        public string? Email { get; set; }
        [EnumDataType(typeof(ClientStatus))]
        public ClientStatus Status { get; set; } = ClientStatus.Active;
    }
}