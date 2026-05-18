import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import 'app_session.dart';
import 'auth_service.dart';
import 'image_moderation_service.dart';

class UserProfileService {
  UserProfileService({AuthService? authService})
    : _authService = authService ?? AuthService(),
      _imageModerationService = ImageModerationService(
        authService: authService ?? AuthService(),
      );

  final AuthService _authService;
  final ImageModerationService _imageModerationService;

  Map<String, String> _authHeaders({bool jsonBody = false}) {
    final token = AppSession.token.trim();
    final headers = <String, String>{};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<UserProfile> getProfile({required String userId}) async {
    final response = await _getWithFallback(path: '/api/users/$userId/profile');
    return _decodeProfile(response);
  }

  Future<UserProfile> uploadProfilePhoto({
    required String userId,
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    await _imageModerationService.ensureImageIsAllowed(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    final response = await _multipartWithFallback(
      path: '/api/users/$userId/profile-photo',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    return _decodeProfile(response);
  }

  Future<UserProfile> updateProfile({
    required String userId,
    required String fullName,
    required String email,
    String? phone,
    String? address,
  }) async {
    final response = await _putWithFallback(
      path: '/api/users/$userId/profile',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone?.trim(),
        'address': address?.trim(),
      },
    );
    return _decodeProfile(response);
  }

  Future<UserProfile> patchUserSettings({
    required String userId,
    required bool notificationEnabled,
  }) async {
    final response = await _patchWithFallback(
      path: '/api/users/$userId/settings',
      body: {'notificationEnabled': notificationEnabled},
    );
    return _decodeProfile(response);
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        return await http
            .get(Uri.parse('$baseUrl$path'), headers: _authHeaders())
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('UserProfileService GET hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya baglanilamadi. Lutfen baglantinizi kontrol edin.',
    );
  }

  Future<http.Response> _multipartWithFallback({
    required String path,
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl$path'),
        );
        if (kIsWeb) {
          final bytes = fileBytes ?? await XFile(filePath).readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: fileName ?? 'profile.jpg',
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', filePath),
          );
        }

        final auth = _authHeaders();
        auth.forEach((key, value) {
          request.headers[key] = value;
        });

        final streamedResponse = await request.send();
        final body = await streamedResponse.stream.bytesToString();
        final wrapped = http.Response(body, streamedResponse.statusCode);
        if (wrapped.statusCode >= 200 && wrapped.statusCode < 300) {
          return wrapped;
        }
        if (kDebugMode) {
          debugPrint(
            'UserProfileService UPLOAD cevap hata ($baseUrl): ${wrapped.statusCode} ${wrapped.body}',
          );
        }
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('UserProfileService UPLOAD hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya baglanilamadi. Lutfen baglantinizi kontrol edin.',
    );
  }

  Future<http.Response> _putWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        return await http
            .put(
              Uri.parse('$baseUrl$path'),
              headers: _authHeaders(jsonBody: true),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('UserProfileService PUT hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya baglanilamadi. Lutfen baglantinizi kontrol edin.',
    );
  }

  Future<http.Response> _patchWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        return await http
            .patch(
              Uri.parse('$baseUrl$path'),
              headers: _authHeaders(jsonBody: true),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('UserProfileService PATCH hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya baglanilamadi. Lutfen baglantinizi kontrol edin.',
    );
  }

  UserProfile _decodeProfile(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    }

    throw AuthException(_extractMessage(response));
  }

  String _extractMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    if (response.body.isNotEmpty) {
      return response.body;
    }
    return 'Islem sirasinda bir hata olustu.';
  }
}
