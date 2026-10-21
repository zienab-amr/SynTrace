using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class addJiraConnectionType1 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "JiraConnectionType",
                table: "JiraConnections",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "JiraConnectionType",
                table: "JiraConnections");
        }
    }
}
