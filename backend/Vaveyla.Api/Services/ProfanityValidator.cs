using System.Globalization;
using System.Text.RegularExpressions;

namespace Vaveyla.Api.Services;

public static class ProfanityValidator
{
    private static readonly string[] Blacklist =
    [
        "amk", "aq", "orospu", "piç", "pic", "sik", "sikeyim", "siktir", "göt", "got",
        "yarrak", "yarrrak", "mal", "salak", "aptal", "gerizekali", "gerizekalı",
        "kahpe", "pezevenk", "ibne", "oc", "oç", "anan", "ananı", "ananizi",
        "serefsiz", "şerefsiz", "haysiyetsiz", "it", "köpek", "kopek",
    ];

    public static bool ContainsProfanity(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        var normalized = Normalize(text);
        foreach (var word in Blacklist)
        {
            if (normalized.Contains(Normalize(word), StringComparison.Ordinal))
            {
                return true;
            }
        }

        return false;
    }

    public static void EnsureClean(string? text, string fieldLabel = "Metin")
    {
        if (ContainsProfanity(text))
        {
            throw new InvalidOperationException(
                $"{fieldLabel} uygunsuz ifadeler içeremez. Lütfen saygılı bir dil kullanın.");
        }
    }

    private static string Normalize(string input)
    {
        var lower = input.ToLower(new CultureInfo("tr-TR"));
        lower = lower
            .Replace('ı', 'i')
            .Replace('ğ', 'g')
            .Replace('ü', 'u')
            .Replace('ş', 's')
            .Replace('ö', 'o')
            .Replace('ç', 'c');
        return Regex.Replace(lower, @"[^a-z0-9]+", " ");
    }
}
