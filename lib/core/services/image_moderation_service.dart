import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

class ImageModerationService {
  ImageModerationService({AuthService? authService})
    : _authService = authService ?? AuthService();

  static const String blockedMessage =
      'Uygunsuz içerik tespit edildi. Profil fotoğrafı olarak çıplaklık veya cinsel içerik kullanılamaz.';

  static const String generalBlockedMessage =
      'Uygunsuz içerik tespit edildi. Lütfen farklı bir fotoğraf seçin.';

  static const String profileCheckUnavailableMessage =
      'Profil fotoğrafı güvenlik kontrolünden geçirilemedi. Lütfen daha sonra tekrar deneyin.';

  final AuthService _authService;

  Future<void> ensureImageIsAllowed({
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final result = await _checkImage(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      purpose: _ModerationPurpose.general,
    );

    if (!result.allowed) {
      throw AuthException(generalBlockedMessage);
    }
  }

  Future<void> ensureProfilePhotoIsAllowed({
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final result = await _checkImage(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      purpose: _ModerationPurpose.profile,
    );

    if (!result.allowed) {
      throw AuthException(
        result.reason == 'nsfw_detected'
            ? blockedMessage
            : profileCheckUnavailableMessage,
      );
    }
  }

  Future<_ModerationResult> _checkImage({
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
    required _ModerationPurpose purpose,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(
            '$baseUrl/api/moderation/check-image?purpose=${purpose.queryValue}',
          ),
        );

        if (kIsWeb) {
          final bytes = fileBytes ?? await XFile(filePath).readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: fileName ?? 'upload.jpg',
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', filePath),
          );
        }

        final response = await request.send();
        final body = await response.stream.bytesToString();
        final wrapped = http.Response(body, response.statusCode);
        if (wrapped.statusCode >= 200 && wrapped.statusCode < 300) {
          return _parseResult(wrapped.body, purpose: purpose);
        }
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('ImageModerationService check error ($baseUrl): $error');
        }
      }
    }

    if (purpose == _ModerationPurpose.profile) {
      throw AuthException(profileCheckUnavailableMessage);
    }

    throw AuthException(
      'Görsel moderasyon servisine ulaşılamadı. Lütfen tekrar deneyin.',
    );
  }

  _ModerationResult _parseResult(
    String body, {
    required _ModerationPurpose purpose,
  }) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        if (data['allowed'] == true) {
          return const _ModerationResult(allowed: true);
        }

        final reason = data['reason']?.toString();
        if (purpose == _ModerationPurpose.profile) {
          return _ModerationResult(allowed: false, reason: reason);
        }
        if (reason == 'moderation_unavailable' ||
            reason == 'moderation_skipped' ||
            reason == 'moderation_disabled' ||
            reason == 'invalid_response') {
          return const _ModerationResult(allowed: true);
        }

        return _ModerationResult(allowed: false, reason: reason);
      }
    } catch (_) {}

    return purpose == _ModerationPurpose.profile
        ? const _ModerationResult(
            allowed: false,
            reason: 'invalid_response',
          )
        : const _ModerationResult(allowed: true);
  }
}

enum _ModerationPurpose {
  general,
  profile;

  String get queryValue => this == _ModerationPurpose.profile ? 'profile' : 'general';
}

class _ModerationResult {
  const _ModerationResult({required this.allowed, this.reason});

  final bool allowed;
  final String? reason;
}
