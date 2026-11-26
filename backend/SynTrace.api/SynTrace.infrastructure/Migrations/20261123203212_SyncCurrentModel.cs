
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations
{
    public partial class SyncCurrentModel : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // RowVersion was already created by
            // CompleteConversationHistory.
            // No database schema changes are needed.
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // No database changes to revert.
        }
    }
}
