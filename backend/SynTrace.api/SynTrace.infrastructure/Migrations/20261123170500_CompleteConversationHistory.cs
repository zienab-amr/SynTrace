using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SynTrace.Infrastructure.Migrations;

/// <summary>
/// The uploaded AddConversationConcurrency migration was empty and its snapshot lacked
/// these columns; this NEW migration works even if that empty migration was already applied.
/// </summary>
public partial class CompleteConversationHistory : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<long>(
            name: "NextSequenceNumber", table: "Conversations", type: "bigint",
            nullable: false, defaultValue: 1L);

        migrationBuilder.AddColumn<byte[]>(
            name: "RowVersion", table: "Conversations", type: "rowversion",
            rowVersion: true, nullable: false);

        migrationBuilder.AddColumn<long>(
            name: "SequenceNumber", table: "ConversationMessages", type: "bigint",
            nullable: false, defaultValue: 0L);

        // Backfill any messages created before sequence support. Stable chronological order.
        migrationBuilder.Sql(@"
WITH OrderedMessages AS
(
    SELECT [ConversationMessageId],
           ROW_NUMBER() OVER
             (PARTITION BY [ConversationId] ORDER BY [CreatedAt], [ConversationMessageId]) AS [NewSequence]
    FROM [ConversationMessages]
)
UPDATE m
   SET m.[SequenceNumber] = o.[NewSequence]
  FROM [ConversationMessages] AS m
  JOIN OrderedMessages AS o ON m.[ConversationMessageId] = o.[ConversationMessageId];

UPDATE c SET c.[NextSequenceNumber] = ISNULL(
  (SELECT MAX(m.[SequenceNumber]) FROM [ConversationMessages] m WHERE m.[ConversationId] = c.[Id]), 0) + 1
FROM [Conversations] AS c;");

        migrationBuilder.CreateIndex(
            name: "IX_ConversationMessages_ConversationId_SequenceNumber",
            table: "ConversationMessages",
            columns: new[] { "ConversationId", "SequenceNumber" },
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(name: "IX_ConversationMessages_ConversationId_SequenceNumber",
            table: "ConversationMessages");
        migrationBuilder.DropColumn(name: "SequenceNumber", table: "ConversationMessages");
        migrationBuilder.DropColumn(name: "RowVersion", table: "Conversations");
        migrationBuilder.DropColumn(name: "NextSequenceNumber", table: "Conversations");
    }
}
