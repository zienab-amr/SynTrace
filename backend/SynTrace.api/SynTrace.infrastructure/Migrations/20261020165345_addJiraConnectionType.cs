using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class addJiraConnectionType : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ConnectionType",
                table: "JiraOAuthStates",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ConnectionType",
                table: "JiraOAuthStates");
        }
    }
}
