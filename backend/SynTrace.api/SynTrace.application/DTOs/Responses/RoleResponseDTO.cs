namespace SynTrace.Application.DTOs.Responses;

public sealed record RoleResponseDTO(string Id, string? Name, string? NormalizedName, string CompanyId);
