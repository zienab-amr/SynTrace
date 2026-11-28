using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Identity;
using SynTrace.Infrastructure.Services.Meetings;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Repositories;

internal static class IdentityChecks
{
    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddDbContext<SynTraceDbContext>(options => options.UseSqlite(connection));
        services.AddIdentityCore<Employee>().AddRoles<Role>().AddEntityFrameworkStores<SynTraceDbContext>()
            .AddDefaultTokenProviders();
        services.AddSingleton<IDataProtectionProvider>(new EphemeralDataProtectionProvider());
        services.AddSingleton<ICurrentTenant>(new TestTenant());
        services.AddSingleton<ICurrentEmployee>(new TestActor());
        services.AddSingleton<IEmailService, TestEmail>();
        services.AddScoped<IOTPService, OTPService>();
        services.AddScoped<ProjectIntegrationAccess>();
        services.AddScoped<EmployeeRepository>();
        services.AddScoped<ForgotPasswordService>();

        await using var provider = services.BuildServiceProvider();
        await using var scope = provider.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
        var users = scope.ServiceProvider.GetRequiredService<UserManager<Employee>>();
        var email = (TestEmail)scope.ServiceProvider.GetRequiredService<IEmailService>();
        var otp = scope.ServiceProvider.GetRequiredService<IOTPService>();
        await db.Database.EnsureCreatedAsync();

        const string newEmail = "new-user@example.test";
        await otp.SendOTP(new OTPRequestDTO { Email = newEmail });
        await AssertStatusAsync(429, () => otp.SendOTP(new OTPRequestDTO { Email = newEmail }));
        var verified = await otp.VerifyOTP(new VerifyOTPRequestDTO { Email = newEmail, OTP = email.Codes[newEmail] });
        Check(verified.Verified && verified.VerificationToken is not null, "Registration must issue a bound proof.");
        Check(!await otp.ConsumeRegistrationAsync("other@example.test", verified.VerificationToken, null),
            "Registration proof must be bound to the verified email.");
        Check(await otp.ConsumeRegistrationAsync(newEmail, verified.VerificationToken, null),
            "Registration proof must be accepted once.");
        Check(!await otp.ConsumeRegistrationAsync(newEmail, verified.VerificationToken, null),
            "Registration proof must be single-use.");

        db.AddRange(new Company { CompanyId = "a", CompanyName = "A" }, new Company { CompanyId = "b", CompanyName = "B" });
        await db.SaveChangesAsync();
        var adminA = MakeEmployee("admin-a", "a");
        var adminB = MakeEmployee("admin-b", "b");
        var member = MakeEmployee("member-a", "a");
        const string oldPassword = "Initial-Password4";
        foreach (var employee in new[] { adminA, adminB, member })
            Check((await users.CreateAsync(employee, oldPassword)).Succeeded, "Identity test setup must create its employees.");

        var roleA = new Role { Id = "admin-role-a", CompanyId = "a", Name = "Admin", NormalizedName = "ADMIN" };
        var roleB = new Role { Id = "admin-role-b", CompanyId = "b", Name = "Admin", NormalizedName = "ADMIN" };
        var memberRole = new Role { Id = "member-role-a", CompanyId = "a", Name = "Member", NormalizedName = "MEMBER" };
        db.AddRange(roleA, roleB, memberRole);
        db.UserRoles.AddRange(
            new IdentityUserRole<string> { UserId = adminA.Id, RoleId = roleA.Id },
            new IdentityUserRole<string> { UserId = adminB.Id, RoleId = roleB.Id },
            new IdentityUserRole<string> { UserId = member.Id, RoleId = memberRole.Id });
        await db.SaveChangesAsync();

        // Meeting permissions are opt-in, stored per role and scoped to the current company.
        var meetingPermissions = new MeetingPermissionService(db, new TestTenant(), new TestActor(),
            new ProjectIntegrationAccess(db));
        Check((await meetingPermissions.GetForEmployeeAsync("a", member.Id, default)).Count == 0,
            "Meeting permissions must default to deny.");
        await AssertStatusAsync(404, () => meetingPermissions.ReplaceForRoleAsync(roleB.Id,
            [MeetingPermission.Approve], default));
        await AssertStatusAsync(400, () => meetingPermissions.ReplaceForRoleAsync(memberRole.Id,
            ["Meetings.Unknown"], default));
        await meetingPermissions.ReplaceForRoleAsync(memberRole.Id, [MeetingPermission.UseAgent], default);
        var meetingGrants = await meetingPermissions.GetForEmployeeAsync("a", member.Id, default);
        var aiPermissions = MeetingAssistantPermissions.From(meetingGrants);
        Check(aiPermissions.CanUseMeetingAgent && !aiPermissions.CanApproveMeeting &&
            !aiPermissions.CanReadApprovedMeetings && !aiPermissions.CanPublishJiraTasks,
            "The AI permissions must reflect only explicit grants.");
        Check((await meetingPermissions.GetForEmployeeAsync("b", member.Id, default)).Count == 0,
            "Meeting permissions must never cross company boundaries.");
        await meetingPermissions.ReplaceForRoleAsync(memberRole.Id, [], default);
        Check((await meetingPermissions.GetForEmployeeAsync("a", member.Id, default)).Count == 0,
            "Revoking a role claim must take effect on the next permission lookup.");

        var directory = scope.ServiceProvider.GetRequiredService<EmployeeRepository>();
        var companyAdmins = await directory.GetEmployeesByRoleAsync("Admin");
        Check(companyAdmins.Count == 1 && companyAdmins[0].Id == adminA.Id,
            "Role queries must resolve duplicate names within the current company.");
        await AssertStatusAsync(404, () => directory.ChangeEmployeeRole(member, roleB.Id));
        await AssertStatusAsync(409, () => directory.ChangeEmployeeRole(adminA, memberRole.Id));
        await directory.ChangeEmployeeRole(member, roleA.Id, memberRole.Id);
        var memberRoles = await directory.GetRolesForEmployeesAsync([member.Id, adminB.Id]);
        Check(memberRoles[member.Id].Single().Id == roleA.Id && !memberRoles.Contains(adminB.Id),
            "Role replacement and directory results must be tenant-scoped.");

        var address = member.Email!;
        await otp.SendOTP(new OTPRequestDTO { Email = address, Purpose = "passwordReset" });
        var resetCode = email.Codes[address];
        var registrationCheck = await otp.VerifyOTP(new VerifyOTPRequestDTO { Email = address, OTP = resetCode });
        Check(!registrationCheck.Verified, "A password reset code cannot issue a registration proof.");
        Check(!await otp.ConsumePasswordResetAsync(address, adminA.Id, resetCode),
            "Password reset code must be bound to the intended employee.");

        var refresh = new RefreshToken
        {
            Id = "refresh-test", EmployeeId = member.Id, Token = "test-fixture",
            ExpiredDate = DateTime.UtcNow.AddDays(1)
        };
        db.RefreshTokens.Add(refresh);
        await db.SaveChangesAsync();

        await using (var rejectedScope = provider.CreateAsyncScope())
        {
            var rejectedReset = rejectedScope.ServiceProvider.GetRequiredService<ForgotPasswordService>();
            await AssertStatusAsync(400, () => rejectedReset.ForgotPasswordAsync(new ForgotPasswordRequestDTO
            {
                Email = address, OTP = resetCode, NewPassword = "weak", ConfirmPassword = "weak"
            }));
        }

        var forgotPassword = scope.ServiceProvider.GetRequiredService<ForgotPasswordService>();
        var originalStamp = member.SecurityStamp;
        const string newPassword = "Replacement-Password4";
        var request = new ForgotPasswordRequestDTO
        {
            Email = address, OTP = resetCode,
            NewPassword = newPassword, ConfirmPassword = newPassword
        };
        await forgotPassword.ForgotPasswordAsync(request);
        Check(await users.CheckPasswordAsync(member, newPassword) && member.SecurityStamp != originalStamp,
            "A password reset must update the credential and invalidate the access-session version.");
        Check(await db.RefreshTokens.AsNoTracking().AnyAsync(x => x.Id == refresh.Id && x.RevokedOn != null),
            "Password reset must revoke existing refresh sessions.");
        await AssertStatusAsync(400, () => forgotPassword.ForgotPasswordAsync(request));

        await otp.SendOTP(new OTPRequestDTO { Email = adminA.Email!, Purpose = "passwordReset" });
        var answer = email.Codes[adminA.Email!];
        var invalid = answer == "123456" ? "654321" : "123456";
        for (var attempt = 0; attempt < 5; attempt++)
            Check(!await otp.ConsumePasswordResetAsync(adminA.Email!, adminA.Id, invalid),
                "An incorrect code must never be accepted.");
        Check(!await otp.ConsumePasswordResetAsync(adminA.Email!, adminA.Id, answer),
            "The correct code must become unavailable after the permitted attempts.");
    }

    private static Employee MakeEmployee(string id, string company)
    {
        var address = id + "@example.test";
        return new Employee { Id = id, FirstName = "Test", LastName = "Employee", UserName = address, Email = address, CompanyId = company };
    }

    private static async Task AssertStatusAsync(int expected, Func<Task> action)
    {
        try
        {
            await action();
        }
        catch (RequestFailureException exception) when (exception.StatusCode == expected)
        {
            return;
        }

        throw new InvalidOperationException($"Expected HTTP status {expected}.");
    }

    private static void Check(bool result, string message)
    {
        if (!result)
            throw new InvalidOperationException(message);
    }

    private sealed class TestTenant : ICurrentTenant
    {
        public string CompanyId => "a";
    }

    private sealed class TestActor : ICurrentEmployee
    {
        public string EmployeeId => "admin-a";
    }

    private sealed class TestEmail : IEmailService
    {
        public Dictionary<string, string> Codes { get; } = [];

        public Task SendOTP(string toEmail, string otp)
        {
            Codes[toEmail] = otp;
            return Task.CompletedTask;
        }
    }
}
