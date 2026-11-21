using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class SharedOAuthAndGitHubIntegration : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GitHubDataOutbox",
                columns: table => new
                {
                    BindingId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    SourceVersion = table.Column<long>(type: "bigint", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ProjectId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    InstallationId = table.Column<long>(type: "bigint", nullable: false),
                    RepositoryId = table.Column<long>(type: "bigint", nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    EntityId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    PayloadJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    OccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubDataOutbox", x => new { x.BindingId, x.SourceVersion });
                });

            migrationBuilder.CreateTable(
                name: "GitHubEmployeeIdentities",
                columns: table => new
                {
                    CompanyId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    EmployeeId = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    GitHubUserId = table.Column<long>(type: "bigint", nullable: false),
                    GitHubLogin = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubEmployeeIdentities", x => new { x.CompanyId, x.EmployeeId });
                    table.ForeignKey(
                        name: "FK_GitHubEmployeeIdentities_AspNetUsers_EmployeeId",
                        column: x => x.EmployeeId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_GitHubEmployeeIdentities_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "GitHubInstallationOwnerships",
                columns: table => new
                {
                    InstallationId = table.Column<long>(type: "bigint", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubInstallationOwnerships", x => x.InstallationId);
                    table.ForeignKey(
                        name: "FK_GitHubInstallationOwnerships_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "GitHubOAuthCompletions",
                columns: table => new
                {
                    ProofHash = table.Column<string>(type: "char(64)", unicode: false, fixedLength: true, maxLength: 64, nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    EmployeeId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Purpose = table.Column<int>(type: "int", nullable: false),
                    GitHubUserId = table.Column<long>(type: "bigint", nullable: false),
                    GitHubLogin = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    EligibleInstallationsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubOAuthCompletions", x => x.ProofHash);
                });

            migrationBuilder.CreateTable(
                name: "GitHubRepositoryBindings",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(36)", maxLength: 36, nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ProjectId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    InstallationId = table.Column<long>(type: "bigint", nullable: false),
                    RepositoryId = table.Column<long>(type: "bigint", nullable: false),
                    Owner = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(513)", maxLength: 513, nullable: false),
                    DefaultBranch = table.Column<string>(type: "nvarchar(1024)", maxLength: 1024, nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubRepositoryBindings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GitHubRepositoryBindings_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                    table.ForeignKey(
                        name: "FK_GitHubRepositoryBindings_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "ProjectId");
                });

            migrationBuilder.CreateTable(
                name: "GitHubRepositorySync",
                columns: table => new
                {
                    BindingId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    RequestedVersion = table.Column<long>(type: "bigint", nullable: false),
                    CompletedVersion = table.Column<long>(type: "bigint", nullable: false),
                    RunningVersion = table.Column<long>(type: "bigint", nullable: false),
                    ProducedVersion = table.Column<long>(type: "bigint", nullable: false),
                    Phase = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    NextPage = table.Column<int>(type: "int", nullable: false),
                    TargetHeadSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    LastIndexedHeadSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    LeaseToken = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    LeaseUntilUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DueAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastSuccessAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LastFailure = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                    ConsecutiveFailures = table.Column<int>(type: "int", nullable: false),
                    Revoked = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubRepositorySync", x => x.BindingId);
                });

            migrationBuilder.CreateTable(
                name: "GitHubSyncedItems",
                columns: table => new
                {
                    BindingId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    EntityId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    PayloadJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    SourceVersion = table.Column<long>(type: "bigint", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubSyncedItems", x => new { x.BindingId, x.Kind, x.EntityId });
                });

            migrationBuilder.CreateTable(
                name: "GitHubWebhookDeliveries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    InstallationId = table.Column<long>(type: "bigint", nullable: false),
                    RepositoryId = table.Column<long>(type: "bigint", nullable: true),
                    BindingId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    EventName = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Action = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: true),
                    ReceivedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    NextDispatchAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastPublishedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DispatchLeaseId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    DispatchLeaseUntilUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ProcessingLeaseId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ProcessingLeaseUntilUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ProcessingNotBeforeUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CompletedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DeadLetteredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ProcessingAttempts = table.Column<int>(type: "int", nullable: false),
                    SendToDeadLetter = table.Column<bool>(type: "bit", nullable: false),
                    LastFailureType = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubWebhookDeliveries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "OAuthStates",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    StateHash = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: false),
                    Provider = table.Column<int>(type: "int", nullable: false),
                    Purpose = table.Column<int>(type: "int", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    EmployeeId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    EncryptedCodeVerifier = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ConsumedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OAuthStates", x => x.Id);
                    table.ForeignKey(
                        name: "FK_OAuthStates_AspNetUsers_EmployeeId",
                        column: x => x.EmployeeId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_OAuthStates_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "GitHubConnections",
                columns: table => new
                {
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    InstallationId = table.Column<long>(type: "bigint", nullable: false),
                    GitHubAccountId = table.Column<long>(type: "bigint", nullable: false),
                    GitHubAccountLogin = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    ConnectedByEmployeeId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    IsSuspended = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    VerifiedRepositoryIdsJson = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GitHubConnections", x => x.CompanyId);
                    table.ForeignKey(
                        name: "FK_GitHubConnections_AspNetUsers_ConnectedByEmployeeId",
                        column: x => x.ConnectedByEmployeeId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_GitHubConnections_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                    table.ForeignKey(
                        name: "FK_GitHubConnections_GitHubInstallationOwnerships_InstallationId",
                        column: x => x.InstallationId,
                        principalTable: "GitHubInstallationOwnerships",
                        principalColumn: "InstallationId");
                });

            migrationBuilder.CreateIndex(
                name: "IX_GitHubConnections_ConnectedByEmployeeId",
                table: "GitHubConnections",
                column: "ConnectedByEmployeeId");

            migrationBuilder.CreateIndex(
                name: "IX_GitHubConnections_InstallationId",
                table: "GitHubConnections",
                column: "InstallationId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GitHubDataOutbox_OccurredAtUtc",
                table: "GitHubDataOutbox",
                column: "OccurredAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_GitHubEmployeeIdentities_CompanyId_GitHubUserId",
                table: "GitHubEmployeeIdentities",
                columns: new[] { "CompanyId", "GitHubUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GitHubEmployeeIdentities_EmployeeId",
                table: "GitHubEmployeeIdentities",
                column: "EmployeeId");

            migrationBuilder.CreateIndex(
                name: "IX_GitHubInstallationOwnerships_CompanyId",
                table: "GitHubInstallationOwnerships",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_GitHubOAuthCompletions_ExpiresAt",
                table: "GitHubOAuthCompletions",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_GitHubRepositoryBindings_CompanyId_RepositoryId",
                table: "GitHubRepositoryBindings",
                columns: new[] { "CompanyId", "RepositoryId" },
                unique: true,
                filter: "[IsActive] = 1");

            migrationBuilder.CreateIndex(
                name: "IX_GitHubRepositoryBindings_InstallationId_RepositoryId_IsActive",
                table: "GitHubRepositoryBindings",
                columns: new[] { "InstallationId", "RepositoryId", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_GitHubRepositoryBindings_ProjectId",
                table: "GitHubRepositoryBindings",
                column: "ProjectId",
                unique: true,
                filter: "[IsActive] = 1");

            migrationBuilder.CreateIndex(
                name: "IX_GitHubRepositorySync_Revoked_DueAtUtc",
                table: "GitHubRepositorySync",
                columns: new[] { "Revoked", "DueAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_GitHubWebhookDeliveries_NextDispatchAtUtc_CompletedAtUtc_DeadLetteredAtUtc",
                table: "GitHubWebhookDeliveries",
                columns: new[] { "NextDispatchAtUtc", "CompletedAtUtc", "DeadLetteredAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_GitHubWebhookDeliveries_ReceivedAtUtc",
                table: "GitHubWebhookDeliveries",
                column: "ReceivedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_OAuthStates_CompanyId",
                table: "OAuthStates",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_OAuthStates_EmployeeId",
                table: "OAuthStates",
                column: "EmployeeId");

            migrationBuilder.CreateIndex(
                name: "IX_OAuthStates_ExpiresAt",
                table: "OAuthStates",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_OAuthStates_StateHash",
                table: "OAuthStates",
                column: "StateHash",
                unique: true);
            migrationBuilder.Sql(
                """
                EXEC(N'
                    INSERT INTO [OAuthStates]
                        ([Id], [StateHash], [Provider], [Purpose], [CompanyId], [EmployeeId], [ExpiresAt], [ConsumedAt])
                    SELECT [JiraOAuthStateId], [StateHash], 0, [ConnectionType], [CompanyId], [EmployeeId],
                        [ExpiresAt], [ConsumedAt]
                    FROM [JiraOAuthStates];
                ');
                """);

            migrationBuilder.DropTable(
                name: "JiraOAuthStates");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GitHubConnections");

            migrationBuilder.DropTable(
                name: "GitHubDataOutbox");

            migrationBuilder.DropTable(
                name: "GitHubEmployeeIdentities");

            migrationBuilder.DropTable(
                name: "GitHubOAuthCompletions");

            migrationBuilder.DropTable(
                name: "GitHubRepositoryBindings");

            migrationBuilder.DropTable(
                name: "GitHubRepositorySync");

            migrationBuilder.DropTable(
                name: "GitHubSyncedItems");

            migrationBuilder.DropTable(
                name: "GitHubWebhookDeliveries");

            migrationBuilder.DropTable(
                name: "GitHubInstallationOwnerships");

            migrationBuilder.CreateTable(
                name: "JiraOAuthStates",
                columns: table => new
                {
                    JiraOAuthStateId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    EmployeeId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ConnectionType = table.Column<int>(type: "int", nullable: false),
                    ConsumedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    StateHash = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraOAuthStates", x => x.JiraOAuthStateId);
                    table.ForeignKey(
                        name: "FK_JiraOAuthStates_AspNetUsers_EmployeeId",
                        column: x => x.EmployeeId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_JiraOAuthStates_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateIndex(
                name: "IX_JiraOAuthStates_CompanyId",
                table: "JiraOAuthStates",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_JiraOAuthStates_EmployeeId",
                table: "JiraOAuthStates",
                column: "EmployeeId");
            migrationBuilder.Sql(
                """
                EXEC(N'
                    INSERT INTO [JiraOAuthStates]
                        ([JiraOAuthStateId], [StateHash], [ConnectionType], [CompanyId], [EmployeeId], [ExpiresAt], [ConsumedAt])
                    SELECT [Id], [StateHash], [Purpose], [CompanyId], [EmployeeId], [ExpiresAt], [ConsumedAt]
                    FROM [OAuthStates] WHERE [Provider] = 0;
                ');
                """);

            migrationBuilder.DropTable(
                name: "OAuthStates");
        }
    }
}
