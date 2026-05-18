import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'connectivity_service.dart';

class ApiHttpClient {
  ApiHttpClient({
    this.timeout = const Duration(seconds: 12),
    this.maxRetries = 2,
  });

  final Duration timeout;
  final int maxRetries;

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) =>
      _execute(() => http.get(uri, headers: headers));

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _execute(() => http.post(uri, headers: headers, body: body));

  Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _execute(() => http.put(uri, headers: headers, body: body));

  Future<http.Response> delete(Uri uri, {Map<String, String>? headers}) =>
      _execute(() => http.delete(uri, headers: headers));

  Future<http.Response> _execute(
    Future<http.Response> Function() request,
  ) async {
    if (!ConnectivityService.instance.isOnline) {
      throw const SocketException('İnternet bağlantısı yok.');
    }

    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await request().timeout(timeout);
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == maxRetries) rethrow;
      } on SocketException catch (e) {
        lastError = e;
        if (attempt == maxRetries) rethrow;
      } on http.ClientException catch (e) {
        lastError = e;
        if (attempt == maxRetries) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    throw lastError ?? const SocketException('Bağlantı hatası');
  }

  static Map<String, dynamic>? decodeJsonMap(http.Response response) {
    if (response.body.isEmpty) return null;
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
    return null;
  }
}
