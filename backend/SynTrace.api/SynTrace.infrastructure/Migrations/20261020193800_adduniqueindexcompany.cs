using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class adduniqueindexcompany : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_JiraConnections_CompanyId",
                table: "JiraConnections");

            migrationBuilder.CreateIndex(
                name: "IX_JiraConnections_CompanyId",
                table: "JiraConnections",
                column: "CompanyId",
                unique: true,
                filter: "[JiraConnectionType] = 0 AND [status] = 1");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_JiraConnections_CompanyId",
                table: "JiraConnections");

            migrationBuilder.CreateIndex(
                name: "IX_JiraConnections_CompanyId",
                table: "JiraConnections",
                column: "CompanyId");
        }
    }
}
