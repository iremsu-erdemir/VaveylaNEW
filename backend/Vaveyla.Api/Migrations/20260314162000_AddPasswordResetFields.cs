using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Vaveyla.Api.Data;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(VaveylaDbContext))]
    [Migration("20260314162000_AddPasswordResetFields")]
    public partial class AddPasswordResetFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PasswordResetCodeHash",
                table: "Users",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PasswordResetCodeExpiresAtUtc",
                table: "Users",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PasswordResetVerifiedAtUtc",
                table: "Users",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PasswordResetCodeHash",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PasswordResetCodeExpiresAtUtc",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PasswordResetVerifiedAtUtc",
                table: "Users");
        }
    }
}
