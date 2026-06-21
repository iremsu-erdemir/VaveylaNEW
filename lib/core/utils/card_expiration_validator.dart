String? validateCardExpirationMMYY(
  String? value, {
  DateTime? now,
  String invalidFormatMessage = 'Son kullanma tarihi MM/YY formatında olmalıdır.',
  String expiredMessage = 'Kartın son kullanma tarihi geçmiş olamaz.',
}) {
  final input = (value ?? '').trim();
  if (input.isEmpty) {
    return null;
  }

  final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(input);
  if (match == null) {
    return invalidFormatMessage;
  }

  final month = int.parse(match.group(1)!);
  final year = int.parse(match.group(2)!);
  final currentDate = now ?? DateTime.now();
  final currentYear = currentDate.year % 100;
  final currentMonth = currentDate.month;

  final isPastYear = year < currentYear;
  final isPastMonthInSameYear = year == currentYear && month < currentMonth;
  if (isPastYear || isPastMonthInSameYear) {
    return expiredMessage;
  }

  return null;
}
