using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPendingEntityChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "AdminWebhookLastReceivedAt",
                table: "JiraConnections",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AiImportCompletedAt",
                table: "JiraConnections",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "EncryptedAdminWebhookSecret",
                table: "JiraConnections",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LastSyncError",
                table: "JiraConnections",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "JiraConnections",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SyncStatus",
                table: "JiraConnections",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "WebhookExpiresAt",
                table: "JiraConnections",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "WebhookId",
                table: "JiraConnections",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WebhookSecretHash",
                table: "JiraConnections",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "JiraComments",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    IssueExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    IssueKey = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    AuthorAccountId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    BodyText = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    SourceCreatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    SourceUpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraComments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_JiraComments_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "JiraIssues",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Key = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ProjectExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    ProjectKey = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    Summary = table.Column<string>(type: "nvarchar(1024)", maxLength: 1024, nullable: true),
                    Status = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    AssigneeAccountId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    SourceUpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraIssues", x => x.Id);
                    table.ForeignKey(
                        name: "FK_JiraIssues_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "JiraProjects",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Key = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    Name = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    ProjectTypeKey = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    LeadAccountId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraProjects", x => x.Id);
                    table.ForeignKey(
                        name: "FK_JiraProjects_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "JiraSprints",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    State = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: true),
                    BoardExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    StartDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CompleteDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraSprints", x => x.Id);
                    table.ForeignKey(
                        name: "FK_JiraSprints_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "JiraUsers",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    AccountId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    DisplayName = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    Active = table.Column<bool>(type: "bit", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraUsers", x => x.Id);
                    table.ForeignKey(
                        name: "FK_JiraUsers_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                });

            migrationBuilder.CreateTable(
                name: "ProcessedJiraEvents",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    JiraConnectionId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    EventId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ProcessedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProcessedJiraEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProcessedJiraEvents_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                    table.ForeignKey(
                        name: "FK_ProcessedJiraEvents_JiraConnections_JiraConnectionId",
                        column: x => x.JiraConnectionId,
                        principalTable: "JiraConnections",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_JiraComments_CompanyId_ExternalId",
                table: "JiraComments",
                columns: new[] { "CompanyId", "ExternalId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_JiraComments_CompanyId_IssueExternalId",
                table: "JiraComments",
                columns: new[] { "CompanyId", "IssueExternalId" });

            migrationBuilder.CreateIndex(
                name: "IX_JiraIssues_CompanyId_ExternalId",
                table: "JiraIssues",
                columns: new[] { "CompanyId", "ExternalId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_JiraIssues_CompanyId_Key",
                table: "JiraIssues",
                columns: new[] { "CompanyId", "Key" });

            migrationBuilder.CreateIndex(
                name: "IX_JiraIssues_CompanyId_ProjectExternalId",
                table: "JiraIssues",
                columns: new[] { "CompanyId", "ProjectExternalId" });

            migrationBuilder.CreateIndex(
                name: "IX_JiraProjects_CompanyId_ExternalId",
                table: "JiraProjects",
                columns: new[] { "CompanyId", "ExternalId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_JiraProjects_CompanyId_Key",
                table: "JiraProjects",
                columns: new[] { "CompanyId", "Key" });

            migrationBuilder.CreateIndex(
                name: "IX_JiraSprints_CompanyId_ExternalId",
                table: "JiraSprints",
                columns: new[] { "CompanyId", "ExternalId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_JiraUsers_CompanyId_AccountId",
                table: "JiraUsers",
                columns: new[] { "CompanyId", "AccountId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProcessedJiraEvents_CompanyId",
                table: "ProcessedJiraEvents",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_ProcessedJiraEvents_ProcessedAt",
                table: "ProcessedJiraEvents",
                column: "ProcessedAt");

            migrationBuilder.CreateIndex(
                name: "UX_ProcessedJiraEvents_Connection_Event",
                table: "ProcessedJiraEvents",
                columns: new[] { "JiraConnectionId", "EventId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "JiraComments");

            migrationBuilder.DropTable(
                name: "JiraIssues");

            migrationBuilder.DropTable(
                name: "JiraProjects");

            migrationBuilder.DropTable(
                name: "JiraSprints");

            migrationBuilder.DropTable(
                name: "JiraUsers");

            migrationBuilder.DropTable(
                name: "ProcessedJiraEvents");

            migrationBuilder.DropColumn(
                name: "AdminWebhookLastReceivedAt",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "AiImportCompletedAt",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "EncryptedAdminWebhookSecret",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "LastSyncError",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "SyncStatus",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "WebhookExpiresAt",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "WebhookId",
                table: "JiraConnections");

            migrationBuilder.DropColumn(
                name: "WebhookSecretHash",
                table: "JiraConnections");
        }
    }
}
