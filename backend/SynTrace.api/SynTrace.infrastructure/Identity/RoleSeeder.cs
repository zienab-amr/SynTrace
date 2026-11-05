using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities;

namespace SynTrace.Infrastructure.Identity
{
    public static class RoleSeeder
    {


        public static async Task SeedRolesAsync(RoleManager<Role> roleManager, string companyId)
        {
           
            string[] roles =
            {
                "Admin",
                "Product Owner",
                "Project Manager",
                "Tech Lead",
                "Developer",
                "QA Engineer",
                "UI/UX Designer",
                "Tester",
            };

            foreach (var role in roles)
            {
                if(!await roleManager.RoleExistsAsync(role))
                {
                    await roleManager.CreateAsync(
                        new Role {
                        Name = role ,
                        CompanyId = companyId
                        });
                }

            }
        }
    }
}
