using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class UserRepository : IUserRepository
{
    private readonly VaveylaDbContext _dbContext;
    private readonly string _connectionString;

    public UserRepository(IConfiguration configuration, VaveylaDbContext dbContext)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' is missing.");
        _dbContext = dbContext;
    }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT UserId, FullName, Email, Phone, Address, PasswordHash, ProfilePhotoPath, Role, IsPrivacyPolicyAccepted, IsTermsOfServiceAccepted, CreatedAtUtc,
                   PasswordResetCodeHash, PasswordResetCodeExpiresAtUtc, PasswordResetVerifiedAtUtc,
                   TotalPenaltyPoints, SuspendedUntilUtc, IsPermanentlyBanned, NotificationEnabled
            FROM dbo.Users
            WHERE LOWER(LTRIM(RTRIM(Email))) = LOWER(LTRIM(RTRIM(@Email)))
            """;
        const string legacySql = """
            SELECT UserId, FullName, Email, PasswordHash, ProfilePhotoPath, Role, IsPrivacyPolicyAccepted, IsTermsOfServiceAccepted, CreatedAtUtc,
                   CAST(1 AS bit) AS NotificationEnabled
            FROM dbo.Users
            WHERE LOWER(LTRIM(RTRIM(Email))) = LOWER(LTRIM(RTRIM(@Email)))
            """;

        await using var connection = new SqlConnection(_connectionString);
        try
        {
            return await connection.QuerySingleOrDefaultAsync<User>(
                new CommandDefinition(sql, new { Email = email }, cancellationToken: cancellationToken));
        }
        catch (SqlException ex) when (ex.Number == 207)
        {
            // Backward compatibility: database migration not applied yet.
            return await connection.QuerySingleOrDefaultAsync<User>(
                new CommandDefinition(legacySql, new { Email = email }, cancellationToken: cancellationToken));
        }
    }

    public async Task<User?> GetByIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT UserId, FullName, Email, Phone, Address, PasswordHash, ProfilePhotoPath, Role, IsPrivacyPolicyAccepted, IsTermsOfServiceAccepted, CreatedAtUtc,
                   PasswordResetCodeHash, PasswordResetCodeExpiresAtUtc, PasswordResetVerifiedAtUtc,
                   TotalPenaltyPoints, SuspendedUntilUtc, IsPermanentlyBanned, NotificationEnabled
            FROM dbo.Users
            WHERE UserId = @UserId
            """;
        const string legacySql = """
            SELECT UserId, FullName, Email, PasswordHash, ProfilePhotoPath, Role, IsPrivacyPolicyAccepted, IsTermsOfServiceAccepted, CreatedAtUtc,
                   CAST(1 AS bit) AS NotificationEnabled
            FROM dbo.Users
            WHERE UserId = @UserId
            """;

        await using var connection = new SqlConnection(_connectionString);
        try
        {
            return await connection.QuerySingleOrDefaultAsync<User>(
                new CommandDefinition(sql, new { UserId = userId }, cancellationToken: cancellationToken));
        }
        catch (SqlException ex) when (ex.Number == 207)
        {
            // Backward compatibility: database migration not applied yet.
            return await connection.QuerySingleOrDefaultAsync<User>(
                new CommandDefinition(legacySql, new { UserId = userId }, cancellationToken: cancellationToken));
        }
    }

    public async Task<bool> AnyAdminExistsAsync(CancellationToken cancellationToken)
    {
        return await _dbContext.Users
            .AsNoTracking()
            .AnyAsync(u => u.Role == UserRole.Admin, cancellationToken);
    }

    public async Task<User> CreateAsync(User user, CancellationToken cancellationToken)
    {
        if (user.Role == UserRole.Admin &&
            await AnyAdminExistsAsync(cancellationToken))
        {
            throw new InvalidOperationException("Sistemde zaten bir admin hesabı bulunmaktadır.");
        }

        _dbContext.Users.Add(user);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return user;
    }

    public async Task<User> UpdateAsync(User user, CancellationToken cancellationToken)
    {
        _dbContext.Users.Update(user);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return user;
    }

    public Task UpdatePasswordResetChallengeAsync(
        Guid userId,
        string passwordResetCodeHash,
        DateTime passwordResetCodeExpiresAtUtc,
        CancellationToken cancellationToken)
    {
        return _dbContext.Database.ExecuteSqlInterpolatedAsync(
            $"""
             UPDATE dbo.Users SET
                 PasswordResetCodeHash = {passwordResetCodeHash},
                 PasswordResetCodeExpiresAtUtc = {passwordResetCodeExpiresAtUtc},
                 PasswordResetVerifiedAtUtc = NULL
             WHERE UserId = {userId}
             """,
            cancellationToken);
    }

    public Task UpdatePasswordResetVerifiedAsync(
        Guid userId,
        DateTime verifiedAtUtc,
        CancellationToken cancellationToken)
    {
        return _dbContext.Database.ExecuteSqlInterpolatedAsync(
            $"""
             UPDATE dbo.Users SET PasswordResetVerifiedAtUtc = {verifiedAtUtc}
             WHERE UserId = {userId}
             """,
            cancellationToken);
    }

    public Task UpdatePasswordAndClearResetAsync(
        Guid userId,
        string passwordHash,
        CancellationToken cancellationToken) =>
        UpdatePasswordAndClearResetAsync(userId, passwordHash, string.Empty, cancellationToken);

    public Task UpdatePasswordAndClearResetAsync(
        Guid userId,
        string passwordHash,
        string passwordResetTokenUsedHash,
        CancellationToken cancellationToken)
    {
        var usedHash = string.IsNullOrWhiteSpace(passwordResetTokenUsedHash)
            ? null
            : passwordResetTokenUsedHash;
        return _dbContext.Database.ExecuteSqlInterpolatedAsync(
            $"""
             UPDATE dbo.Users SET
                 PasswordHash = {passwordHash},
                 PasswordResetCodeHash = NULL,
                 PasswordResetCodeExpiresAtUtc = NULL,
                 PasswordResetVerifiedAtUtc = NULL,
                 PasswordResetTokenUsedHash = {usedHash}
             WHERE UserId = {userId}
             """,
            cancellationToken);
    }

    public async Task<List<UserAddress>> GetAddressesAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await _dbContext.UserAddresses
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.IsSelected)
            .ThenByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<UserAddress?> GetAddressByIdAsync(
        Guid userId,
        Guid addressId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.UserAddresses.FirstOrDefaultAsync(
            x => x.UserId == userId && x.AddressId == addressId,
            cancellationToken);
    }

    public async Task<UserAddress> AddAddressAsync(
        UserAddress address,
        CancellationToken cancellationToken)
    {
        _dbContext.UserAddresses.Add(address);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return address;
    }

    public async Task DeleteAddressAsync(UserAddress address, CancellationToken cancellationToken)
    {
        _dbContext.UserAddresses.Remove(address);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<List<PaymentCard>> GetPaymentCardsAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.PaymentCards
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<PaymentCard?> GetPaymentCardByIdAsync(
        Guid userId,
        Guid paymentCardId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.PaymentCards.FirstOrDefaultAsync(
            x => x.UserId == userId && x.PaymentCardId == paymentCardId,
            cancellationToken);
    }

    public async Task<PaymentCard> AddPaymentCardAsync(
        PaymentCard paymentCard,
        CancellationToken cancellationToken)
    {
        _dbContext.PaymentCards.Add(paymentCard);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return paymentCard;
    }

    public async Task DeletePaymentCardAsync(PaymentCard paymentCard, CancellationToken cancellationToken)
    {
        _dbContext.PaymentCards.Remove(paymentCard);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<UserFeedback> AddFeedbackAsync(
        UserFeedback feedback,
        CancellationToken cancellationToken)
    {
        _dbContext.UserFeedbacks.Add(feedback);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return feedback;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
