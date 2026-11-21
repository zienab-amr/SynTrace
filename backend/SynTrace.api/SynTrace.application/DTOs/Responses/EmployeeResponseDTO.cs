namespace SynTrace.Application.DTOs.Responses;

public sealed record EmployeeResponseDTO(
    string Id, string FirstName, string LastName, string? Email,
    string? PhoneNumber, string CompanyId, IReadOnlyList<EmployeeRoleResponseDTO> Roles);

public sealed record EmployeeRoleResponseDTO(string Id, string? Name);
