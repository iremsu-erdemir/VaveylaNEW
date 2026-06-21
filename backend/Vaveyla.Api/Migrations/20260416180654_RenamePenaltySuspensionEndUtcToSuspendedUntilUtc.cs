using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class RenamePenaltySuspensionEndUtcToSuspendedUntilUtc : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "PenaltySuspensionEndUtc",
                table: "Users",
                newName: "SuspendedUntilUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "SuspendedUntilUtc",
                table: "Users",
                newName: "PenaltySuspensionEndUtc");
        }
    }
}
