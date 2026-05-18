using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

/// <summary>
/// Askı / kalıcı ban kontrollerinin tek merkezi. Uygulama genelinde dağınık tarih karşılaştırması yapılmaz.
/// </summary>
public interface IUserSuspensionService
{
    bool IsOperationallyBlocked(User? user);

    /// <summary>Kullanıcı askıda veya kalıcı banlıysa ForbiddenOperationException fırlatır (HTTP 403).</summary>
    void ThrowIfOperationallyBlocked(User? user, string message);

    /// <summary>Mevcut bitişten daha geç bir tarih ise askıyı uzatır.</summary>
    void ExtendSuspensionUntil(User user, DateTime candidateEndUtc);

    /// <summary>
    /// Süresi dolmuş askıları temizler: <c>SuspendedUntilUtc &lt;= UtcNow</c> olanlarda alanı null yapar.
    /// </summary>
    /// <returns>Güncellenen kullanıcı sayısı.</returns>
    Task<int> ClearExpiredSuspensionsAsync(CancellationToken cancellationToken);
}
