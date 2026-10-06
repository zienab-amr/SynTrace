using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace SynTrace.Application.Features.Role.Queries.GetAllRoles
{
    public class GetAllRolesQuery : IRequest<List<IdentityRole>>;

}
