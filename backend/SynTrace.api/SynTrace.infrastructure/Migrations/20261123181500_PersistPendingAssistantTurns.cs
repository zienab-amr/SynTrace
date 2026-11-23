using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations;

public partial class PersistPendingAssistantTurns : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "ClientMessageId", table: "ConversationMessages", type: "nvarchar(64)",
            maxLength: 64, nullable: true);
        migrationBuilder.AddColumn<string>(
            name: "CorrelationId", table: "ConversationMessages", type: "nvarchar(100)",
            maxLength: 100, nullable: true);

        // Previous versions stored AI status (ok/no_results/...) rather than turn lifecycle.
        migrationBuilder.Sql("UPDATE [ConversationMessages] SET [Status] = 'answered' WHERE [Status] NOT IN ('pending', 'answered', 'failed');");

        migrationBuilder.CreateIndex(
            name: "IX_ConversationMessages_ClientMessageId",
            table: "ConversationMessages", column: "ClientMessageId",
            unique: true, filter: "[ClientMessageId] IS NOT NULL");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(name: "IX_ConversationMessages_ClientMessageId",
            table: "ConversationMessages");
        migrationBuilder.DropColumn(name: "ClientMessageId", table: "ConversationMessages");
        migrationBuilder.DropColumn(name: "CorrelationId", table: "ConversationMessages");
    }
}
