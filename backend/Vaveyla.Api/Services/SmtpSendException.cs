namespace Vaveyla.Api.Services;

/// <summary>SMTP gönderimi başarısız olduğunda fırlatılır; kullanıcıya gösterilecek mesaj içerir.</summary>
public sealed class SmtpSendException : Exception
{
    public SmtpSendException(string userMessage, string? logDetail = null, Exception? inner = null)
        : base(logDetail ?? userMessage, inner)
    {
        UserMessage = userMessage;
    }

    public string UserMessage { get; }
}
