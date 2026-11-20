using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Identity;
using SynTrace.Api.Controllers;
using Scalar.AspNetCore;
using SynTrace.Application;
using SynTrace.Infrastructure;
using SynTrace.Infrastructure.Identity;
using SynTrace.Domain.Entities;


var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddApplicationDI();
builder.Services.AddInfrastructureDI(builder.Configuration);
builder.Services.AddControllers();

builder.Services.AddCors(options =>
{
    options.AddPolicy("JiraOAuthTest", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Servers =
        [
            new Microsoft.OpenApi.OpenApiServer
            {
                Url = "/"
            }
        ];

        return Task.CompletedTask;
    });
});
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    // Each question costs an LLM call, so the limit is per employee.
    options.AddPolicy(AssistantController.RateLimitPolicy, context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(1) }));
});

var app = builder.Build();

//using (var scope = app.Services.CreateScope())
//{
//    var roleManager =
//        scope.ServiceProvider
//            .GetRequiredService<RoleManager<Role>>();

//    await RoleSeeder.SeedRolesAsync(roleManager);
//}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseCors("JiraOAuthTest");

app.UseAuthentication();
app.UseAuthorization();

app.UseRateLimiter();

app.MapControllers();

app.Run();