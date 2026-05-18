import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';

String localizeFeedbackMessage(Object message) {
  var text = message.toString().trim();
  text = text.replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');
  if (text.isEmpty) {
    return 'Bir hata oluştu.';
  }

  final lower = text.toLowerCase();
  final hasTurkishChars = RegExp(r'[ığüşöçİĞÜŞÖÇ]').hasMatch(text);
  if (hasTurkishChars) {
    return text;
  }

  if (lower.contains('unauthorized') || lower.contains('401')) {
    return 'Oturum süreniz doldu. Lütfen tekrar giriş yapın.';
  }
  if (lower.contains('forbidden') || lower.contains('403')) {
    return 'Bu işlem için yetkiniz bulunmuyor.';
  }
  if (lower.contains('not found') || lower.contains('404')) {
    return 'Aranan kayıt bulunamadı.';
  }
  if (lower.contains('duplicate') || lower.contains('already')) {
    return 'Bu kayıt zaten mevcut.';
  }
  if (lower.contains('timeout') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('bağlan')) {
    return 'Sunucu bağlantısı kurulamadı. Lütfen internetinizi kontrol edin.';
  }
  if (lower.contains('failed') || lower.contains('error') || lower.contains('hata')) {
    return 'İşlem sırasında bir hata oluştu.';
  }
  if (lower.startsWith('{') || lower.startsWith('<')) {
    return 'İşlem başarısız oldu.';
  }

  return text;
}

extension AppFeedbackExtension on BuildContext {
  void showSuccessMessage(String message) {
    final colors = theme.appColors;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.success,
      ),
    );
  }

  void showInfoMessage(String message) {
    final colors = theme.appColors;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.primary,
      ),
    );
  }

  void showErrorMessage(Object error) {
    final colors = theme.appColors;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(localizeFeedbackMessage(error)),
        backgroundColor: colors.error,
      ),
    );
  }
}
