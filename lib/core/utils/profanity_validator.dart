/// Türkçe küfür/hakaret/argo için temel metin kontrolü (büyük-küçük harf duyarsız).
class ProfanityValidator {
  ProfanityValidator._();

  static const List<String> _blacklist = [
    'amk',
    'aq',
    'orospu',
    'piç',
    'pic',
    'sik',
    'sikeyim',
    'siktir',
    'göt',
    'got',
    'yarrak',
    'mal',
    'salak',
    'aptal',
    'gerizekali',
    'gerizekalı',
    'kahpe',
    'pezevenk',
    'ibne',
    'oc',
    'oç',
    'anan',
    'ananı',
    'ananizi',
    'serefsiz',
    'şerefsiz',
    'haysiyetsiz',
    'köpek',
    'kopek',
  ];

  static const String profanityWarning =
      'Mesajınız uygunsuz ifadeler içeriyor. Lütfen saygılı bir dil kullanın.';

  static bool containsProfanity(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final normalized = _normalize(text);
    for (final word in _blacklist) {
      if (normalized.contains(_normalize(word))) {
        return true;
      }
    }
    return false;
  }

  static String? validateOrNull(String? text) {
    return containsProfanity(text) ? profanityWarning : null;
  }

  static String _normalize(String input) {
    var s = input.toLowerCase();
    const map = {
      'ı': 'i',
      'ğ': 'g',
      'ü': 'u',
      'ş': 's',
      'ö': 'o',
      'ç': 'c',
      'İ': 'i',
      'Ğ': 'g',
      'Ü': 'u',
      'Ş': 's',
      'Ö': 'o',
      'Ç': 'c',
    };
    map.forEach((from, to) {
      s = s.replaceAll(from, to);
    });
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }
}
