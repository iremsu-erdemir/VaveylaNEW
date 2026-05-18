namespace Vaveyla.Api.Exceptions;

/// <summary>İş kuralı: askıda veya kalıcı banlı kullanıcı için operasyon reddedildi (HTTP 403).</summary>
public sealed class ForbiddenOperationException : Exception
{
    public ForbiddenOperationException(string message)
        : base(message)
    {
    }
}
