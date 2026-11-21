using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class BackendReviewFixes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ApiAuditEntries",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    EmployeeId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Operation = table.Column<string>(type: "nvarchar(220)", maxLength: 220, nullable: false),
                    StatusCode = table.Column<int>(type: "int", nullable: false),
                    OccurredAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ApiAuditEntries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "IdentityChallenges",
                columns: table => new
                {
                    Key = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: false),
                    SubjectId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    ProtectedCode = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ProofHash = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: true),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    SendWindowUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    SendsInWindow = table.Column<int>(type: "int", nullable: false),
                    Attempts = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IdentityChallenges", x => x.Key);
                });

            migrationBuilder.CreateTable(
                name: "JiraProjectionWatermarks",
                columns: table => new
                {
                    JiraConnectionId = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Kind = table.Column<int>(type: "int", nullable: false),
                    ExternalId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    SourceOccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastDeletedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraProjectionWatermarks", x => new { x.JiraConnectionId, x.Kind, x.ExternalId })
                        .Annotation("SqlServer:Clustered", false);
                });

            migrationBuilder.CreateTable(
                name: "KnowledgePublicationChanges",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ProjectId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    SourceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Version = table.Column<int>(type: "int", nullable: false),
                    Removed = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_KnowledgePublicationChanges", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "KnowledgeSources",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CompanyId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ClientId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ProjectId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    CreatedByEmployeeId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Kind = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CurrentVersion = table.Column<int>(type: "int", nullable: false),
                    PublishedVersion = table.Column<int>(type: "int", nullable: true),
                    Revision = table.Column<int>(type: "int", nullable: false),
                    Withdrawn = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_KnowledgeSources", x => x.Id);
                    table.ForeignKey(
                        name: "FK_KnowledgeSources_Clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Clients",
                        principalColumn: "ClientId");
                    table.ForeignKey(
                        name: "FK_KnowledgeSources_Companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Companies",
                        principalColumn: "CompanyId");
                    table.ForeignKey(
                        name: "FK_KnowledgeSources_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "ProjectId");
                });

            migrationBuilder.CreateTable(
                name: "KnowledgeSourceVersions",
                columns: table => new
                {
                    SourceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Number = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    MediaType = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Pdf = table.Column<byte[]>(type: "varbinary(max)", nullable: true),
                    MeetingMode = table.Column<int>(type: "int", nullable: true),
                    MeetingAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedByEmployeeId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    FailureCode = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    ReviewedByEmployeeId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    ReviewedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_KnowledgeSourceVersions", x => new { x.SourceId, x.Number });
                    table.ForeignKey(
                        name: "FK_KnowledgeSourceVersions_KnowledgeSources_SourceId",
                        column: x => x.SourceId,
                        principalTable: "KnowledgeSources",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "KnowledgeEvidence",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SourceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Version = table.Column<int>(type: "int", nullable: false),
                    Kind = table.Column<int>(type: "int", nullable: false),
                    Text = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    Quote = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                    QuoteOffset = table.Column<int>(type: "int", nullable: false),
                    Decision = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_KnowledgeEvidence", x => x.Id);
                    table.ForeignKey(
                        name: "FK_KnowledgeEvidence_KnowledgeSourceVersions_SourceId_Version",
                        columns: x => new { x.SourceId, x.Version },
                        principalTable: "KnowledgeSourceVersions",
                        principalColumns: new[] { "SourceId", "Number" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ApiAuditEntries_CompanyId_Id",
                table: "ApiAuditEntries",
                columns: new[] { "CompanyId", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_IdentityChallenges_SendWindowUtc",
                table: "IdentityChallenges",
                column: "SendWindowUtc");

            migrationBuilder.CreateIndex(
                name: "IX_KnowledgeEvidence_SourceId_Version",
                table: "KnowledgeEvidence",
                columns: new[] { "SourceId", "Version" });

            migrationBuilder.CreateIndex(
                name: "IX_KnowledgePublicationChanges_CompanyId_Id",
                table: "KnowledgePublicationChanges",
                columns: new[] { "CompanyId", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_KnowledgeSources_ClientId",
                table: "KnowledgeSources",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_KnowledgeSources_CompanyId_ClientId",
                table: "KnowledgeSources",
                columns: new[] { "CompanyId", "ClientId" });

            migrationBuilder.CreateIndex(
                name: "IX_KnowledgeSources_CompanyId_ProjectId",
                table: "KnowledgeSources",
                columns: new[] { "CompanyId", "ProjectId" });

            migrationBuilder.CreateIndex(
                name: "IX_KnowledgeSources_ProjectId",
                table: "KnowledgeSources",
                column: "ProjectId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ApiAuditEntries");

            migrationBuilder.DropTable(
                name: "IdentityChallenges");

            migrationBuilder.DropTable(
                name: "JiraProjectionWatermarks");

            migrationBuilder.DropTable(
                name: "KnowledgeEvidence");

            migrationBuilder.DropTable(
                name: "KnowledgePublicationChanges");

            migrationBuilder.DropTable(
                name: "KnowledgeSourceVersions");

            migrationBuilder.DropTable(
                name: "KnowledgeSources");
        }
    }
}
