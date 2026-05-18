import 'dart:convert';

/// UUID çıkarma — adres kimliği bazen JSON metni olarak gelir.
final RegExp uuidPattern = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

String? tryExtractUuid(Object? raw) {
  if (raw == null) return null;

  if (raw is Map) {
    final nested = raw['addressId'] ?? raw['AddressId'] ?? raw['userId'] ?? raw['UserId'];
    if (nested != null && nested != raw) {
      return tryExtractUuid(nested);
    }
  }

  var text = raw.toString().trim();
  if (text.isEmpty) return null;

  for (var i = 0; i < 4; i++) {
    final match = uuidPattern.firstMatch(text);
    if (match != null) {
      return match.group(0)!.toLowerCase();
    }

    final decoded = _tryDecodeJson(text);
    if (decoded == null || decoded == text) {
      break;
    }
    text = decoded.trim();
  }

  final match = uuidPattern.firstMatch(text);
  return match?.group(0)?.toLowerCase();
}

String? _tryDecodeJson(String text) {
  if (text.isEmpty) return null;

  try {
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']')) ||
        (text.startsWith('"') && text.endsWith('"'))) {
      final decoded = jsonDecode(text);
      if (decoded is String) {
        return decoded;
      }
      if (decoded is Map) {
        final id =
            decoded['addressId'] ??
            decoded['AddressId'] ??
            decoded['userId'] ??
            decoded['UserId'];
        if (id != null) {
          return id.toString();
        }
        return jsonEncode(decoded);
      }
    }
  } catch (_) {}

  return null;
}

bool isValidUuid(String? value) {
  if (value == null || value.isEmpty) return false;
  final matched = uuidPattern.stringMatch(value);
  return matched != null && matched.length == value.length;
}
