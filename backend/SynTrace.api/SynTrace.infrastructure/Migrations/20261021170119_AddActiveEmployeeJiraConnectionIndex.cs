using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddActiveEmployeeJiraConnectionIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "UX_JiraConnections_ActiveEmployee",
                table: "JiraConnections",
                columns: new[] { "CompanyId", "ConnectedByEmployeeId" },
                unique: true,
                filter: "[JiraConnectionType] = 1 AND [status] = 1");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_JiraConnections_ActiveEmployee",
                table: "JiraConnections");
        }
    }
}
