import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

/// Admin geri bildirim / ceza API.
class AdminFeedbackService {
  AdminFeedbackService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls = baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
      ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
      : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Map<String, String> get _headers {
    final token = AppSession.token;
    if (token.isEmpty) return const {'Content-Type': 'application/json'};
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listFeedbacks() async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/api/admin/feedbacks'), headers: _headers)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
        if (kDebugMode) {
          debugPrint('AdminFeedbackService list: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminFeedbackService list: $e');
      }
    }
    return [];
  }

  /// [action] API `AdminActionType` camelCase: warning, addPenaltyPoints, suspendUser, permanentBan, rejectFeedback
  Future<void> applyAction({
    required String feedbackId,
    required String action,
    int? points,
    int? suspendDays,
    DateTime? suspendUntilUtc,
  }) async {
    final body = <String, dynamic>{'action': action};
    if (points != null) body['points'] = points;
    if (suspendDays != null) body['suspendDays'] = suspendDays;
    if (suspendUntilUtc != null) {
      body['suspendUntilUtc'] = suspendUntilUtc.toUtc().toIso8601String();
    }

    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse(
                '$baseUrl/api/admin/feedbacks/${Uri.encodeComponent(feedbackId)}/action',
              ),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }
        var msg = 'İşlem başarısız (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        throw AuthException(msg);
      } on AuthException {
        rethrow;
      } catch (e) {
        if (kDebugMode) debugPrint('AdminFeedbackService action: $e');
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }
}
