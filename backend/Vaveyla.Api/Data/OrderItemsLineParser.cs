using System.Text.RegularExpressions;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

/// <summary>
/// <see cref="CustomerOrder.Items"/> metnini ("2x Ürün Adı, 1x Diğer") ayrıştırır ve menü satırlarıyla eşleştirir.
/// </summary>
/// <remarks>
/// <para><b>Roadmap (üretim hedefi):</b> Sipariş kalemleri için normalize tablo (ör. CustomerOrderLines:
/// OrderId, MenuItemId, Quantity, UnitPrice) tanımlanmalı; bu parser yalnızca geçmiş veri / geçiş dönemi için
/// kalır. Böylece raporlama, indeks ve öneri motoru SQL tarafında güvenilir şekilde çalışır.</para>
/// </remarks>
public static class OrderItemsLineParser
{
    private static readonly Regex QuantityProductRegex = new(
        @"^\s*(\d+)\s*[xX]\s*(.+?)\s*$",
        RegexOptions.Compiled);

    private static readonly Regex TrailingParenthesesRegex = new(
        @"\s*\([^)]*\)\s*$",
        RegexOptions.Compiled);

    public static IEnumerable<(int Quantity, string ProductName)> ParseItems(string itemsText)
    {
        var parts = itemsText.Split(
            ',',
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        foreach (var part in parts)
        {
            if (string.IsNullOrWhiteSpace(part))
            {
                continue;
            }

            var match = QuantityProductRegex.Match(part);
            if (!match.Success)
            {
                var fallbackName = CleanProductName(part);
                if (!string.IsNullOrWhiteSpace(fallbackName))
                {
                    yield return (1, fallbackName);
                }

                continue;
            }

            var qtyText = match.Groups[1].Value;
            var nameText = match.Groups[2].Value;

            if (!int.TryParse(qtyText, out var qty) || qty <= 0)
            {
                continue;
            }

            var productName = CleanProductName(nameText);
            if (string.IsNullOrWhiteSpace(productName))
            {
                continue;
            }

            yield return (qty, productName);
        }
    }

    public static MenuItem? MatchMenuItem(
        string orderedProductName,
        IReadOnlyDictionary<string, MenuItem> normalizedNameToMenuItem,
        IReadOnlyList<MenuItem> menuItems)
    {
        var normalizedOrdered = NormalizeName(orderedProductName);
        if (normalizedNameToMenuItem.TryGetValue(normalizedOrdered, out var exact))
        {
            return exact;
        }

        var candidates = new List<MenuItem>();
        foreach (var menuItem in menuItems)
        {
            if (string.IsNullOrWhiteSpace(menuItem.Name))
            {
                continue;
            }

            var normalizedMenuName = NormalizeName(menuItem.Name);
            if (normalizedOrdered.Contains(normalizedMenuName) ||
                normalizedMenuName.Contains(normalizedOrdered))
            {
                candidates.Add(menuItem);
            }
        }

        if (candidates.Count == 0)
        {
            return null;
        }

        return candidates
            .OrderByDescending(mi => mi.Name?.Length ?? 0)
            .First();
    }

    public static string CleanProductName(string productName)
    {
        var trimmed = productName.Trim();
        trimmed = TrailingParenthesesRegex.Replace(trimmed, string.Empty);
        return trimmed.Trim();
    }

    public static string NormalizeName(string value) =>
        value.Trim().ToLowerInvariant();
}
