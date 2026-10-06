using Microsoft.AspNetCore.Identity;

namespace SynTrace.Infrastructure.Identity
{
    public static class RoleSeeder
    {

        public static async Task SeedRolesAsync(RoleManager<IdentityRole> roleManager)
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
                    await roleManager.CreateAsync(new IdentityRole(role));
                }

            }
        }
    }
}
