using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface IUserRepository
{
    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken);
    Task<User?> GetByIdAsync(Guid userId, CancellationToken cancellationToken);
    Task<bool> AnyAdminExistsAsync(CancellationToken cancellationToken);
    Task<User> CreateAsync(User user, CancellationToken cancellationToken);
    Task<User> UpdateAsync(User user, CancellationToken cancellationToken);

    /// <summary>
    /// Dapper ile gelen kısmi User grafiğini EF Update ile yazmamak için; yalnızca sıfırlama alanları güncellenir.
    /// </summary>
    Task UpdatePasswordResetChallengeAsync(
        Guid userId,
        string passwordResetCodeHash,
        DateTime passwordResetCodeExpiresAtUtc,
        CancellationToken cancellationToken);

    Task UpdatePasswordResetVerifiedAsync(Guid userId, DateTime verifiedAtUtc, CancellationToken cancellationToken);

    Task UpdatePasswordAndClearResetAsync(Guid userId, string passwordHash, CancellationToken cancellationToken);
    Task<List<UserAddress>> GetAddressesAsync(Guid userId, CancellationToken cancellationToken);
    Task<UserAddress?> GetAddressByIdAsync(Guid userId, Guid addressId, CancellationToken cancellationToken);
    Task<UserAddress> AddAddressAsync(UserAddress address, CancellationToken cancellationToken);
    Task DeleteAddressAsync(UserAddress address, CancellationToken cancellationToken);
    Task<List<PaymentCard>> GetPaymentCardsAsync(Guid userId, CancellationToken cancellationToken);
    Task<PaymentCard?> GetPaymentCardByIdAsync(Guid userId, Guid paymentCardId, CancellationToken cancellationToken);
    Task<PaymentCard> AddPaymentCardAsync(PaymentCard paymentCard, CancellationToken cancellationToken);
    Task DeletePaymentCardAsync(PaymentCard paymentCard, CancellationToken cancellationToken);
    Task<UserFeedback> AddFeedbackAsync(UserFeedback feedback, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
