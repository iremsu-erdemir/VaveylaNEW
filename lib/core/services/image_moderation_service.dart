import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

class ImageModerationService {
  ImageModerationService({AuthService? authService})
    : _authService = authService ?? AuthService();

  static const String blockedMessage =
      'Uygunsuz içerik tespit edildi. Lütfen farklı bir fotoğraf seçin.';

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
    );

    if (!result.allowed) {
      throw AuthException(blockedMessage);
    }
  }

  Future<_ModerationResult> _checkImage({
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/moderation/check-image'),
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
          return _parseResult(wrapped.body);
        }
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('ImageModerationService check error ($baseUrl): $error');
        }
      }
    }

    throw AuthException(
      'Görsel moderasyon servisine ulaşılamadı. Lütfen tekrar deneyin.',
    );
  }

  _ModerationResult _parseResult(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return _ModerationResult(allowed: data['allowed'] == true);
      }
    } catch (_) {}
    return const _ModerationResult(allowed: false);
  }
}

class _ModerationResult {
  const _ModerationResult({required this.allowed});

  final bool allowed;
}
