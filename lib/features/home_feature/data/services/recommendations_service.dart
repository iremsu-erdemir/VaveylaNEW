import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart'
    show AuthException, AuthService;
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/reason_generators.dart';
import 'package:http/http.dart' as http;

class _RecommendationsCacheEntry {
  _RecommendationsCacheEntry(this.result, this.expiresAt);

  final RecommendationResult result;
  final DateTime expiresAt;
}

/// JWT ile öneri listesi; aynı kullanıcı + preference için kısa süreli istemci önbelleği.
class RecommendationsService {
  RecommendationsService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
    IReasonGenerator? ruleBasedReasonGenerator,
    IReasonGenerator? llmReasonGenerator,
    bool enableLLMReasoning = false,
  }) : _baseUrls =
            baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
                ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
                : (authService ?? AuthService()).baseUrls,
       _ruleBasedReasonGenerator = ruleBasedReasonGenerator ?? const RuleBasedReasonGenerator(),
       _llmReasonGenerator = llmReasonGenerator ?? const LLMReasonGenerator(),
       _enableLLMReasoning = enableLLMReasoning;

  static final Map<String, _RecommendationsCacheEntry> _memory =
      <String, _RecommendationsCacheEntry>{};

  static const Duration _clientCacheTtl = Duration(seconds: 90);

  final List<String> _baseUrls;
  final IReasonGenerator _ruleBasedReasonGenerator;
  final IReasonGenerator _llmReasonGenerator;
  bool _enableLLMReasoning;

  bool get enableLLMReasoning => _enableLLMReasoning;

  void setEnableLLMReasoning(bool value) {
    _enableLLMReasoning = value;
  }

  Future<List<RecommendationItem>> getRecommendations({
    String preference = 'any',
  }) async =>
      (await getRecommendationResult(preference: preference)).products;

  Future<RecommendationResult> getRecommendationResult({
    String preference = 'any',
  }) async {
    final token = AppSession.token.trim();
    if (token.isEmpty) {
      throw AuthException('Oturum bulunamadı.');
    }
    final userId = AppSession.userId;
    final pref = preference.trim().toLowerCase();
    final mode = _enableLLMReasoning ? 'llm' : 'rule';
    final cacheKey = '$userId|$pref|$mode';
    final now = DateTime.now();
    final hit = _memory[cacheKey];
    if (hit != null && hit.expiresAt.isAfter(now)) {
      return hit.result;
    }

    final q = Uri.encodeComponent(pref);
    final path = '/api/recommendations?preference=$q';
    final response = await _getWithFallback(path: path, token: token);
    final result = _parseAndBuildResult(
      responseBody: response.body,
      preference: pref,
    );
    _memory[cacheKey] = _RecommendationsCacheEntry(
      result,
      now.add(_clientCacheTtl),
    );
    return result;
  }

  RecommendationResult _parseAndBuildResult({
    required String responseBody,
    required String preference,
  }) {
    final data = jsonDecode(responseBody);
    if (data is! Map<String, dynamic>) {
      return _emptyResult(preference, 'Yanıt formatı geçersiz.');
    }

    final rawProducts = data['products'] ?? data['items'];
    if (rawProducts is! List) {
      return _emptyResult(preference, 'Öneri listesi bulunamadı.');
    }

    final baseList = rawProducts
        .whereType<Map<String, dynamic>>()
        .map(RecommendationItem.fromJson)
        .toList();

    final list = baseList
        .map(
          (item) => item.copyWith(
            reason: _resolveReason(item: item, preference: preference),
          ),
        )
        .toList();

    final availableFilters = _extractAvailableFilters(data, list);
    _logRecommendationDebug(
      preference: preference,
      appliedFilter: data['appliedFilter']?.toString() ?? 'unknown',
      excludedProductNames: (data['excludedProducts'] is List)
          ? (data['excludedProducts'] as List<dynamic>).map((e) => e.toString()).toList()
          : const <String>[],
      finalProducts: list,
    );

    return RecommendationResult(
      products: list,
      appliedFilter: data['appliedFilter']?.toString() ?? 'unknown',
      excludedProducts: (data['excludedProducts'] is List)
          ? (data['excludedProducts'] as List<dynamic>).map((e) => e.toString()).toList()
          : const <String>[],
      reason: data['reason']?.toString() ?? '',
      availableFilters: availableFilters,
    );
  }

  Future<http.Response> _getWithFallback({
    required String path,
    required String token,
  }) async {
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      if (kDebugMode) {
        debugPrint('[API DEBUG] RecommendationsService GET: $url');
      }
      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: <String, String>{
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 401) {
          throw AuthException('Oturum süreniz doldu. Lütfen tekrar giriş yapın.');
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
      } on AuthException {
        rethrow;
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('RecommendationsService GET hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Öneriler yüklenemedi.');
  }

  String _resolveReason({
    required RecommendationItem item,
    required String preference,
  }) {
    if (_enableLLMReasoning) {
      final llmReason = _llmReasonGenerator.generate(
        item: item,
        preference: preference,
      );
      if (llmReason.trim().isNotEmpty) {
        return llmReason;
      }
    }

    return _ruleBasedReasonGenerator.generate(
      item: item,
      preference: preference,
    );
  }

  RecommendationResult _emptyResult(String preference, String reason) {
    return RecommendationResult(
      products: const <RecommendationItem>[],
      appliedFilter: 'sweet/$preference',
      excludedProducts: const <String>[],
      reason: reason,
      availableFilters: _defaultFilters(),
    );
  }

  List<RecommendationFilterOption> _extractAvailableFilters(
    Map<String, dynamic> data,
    List<RecommendationItem> products,
  ) {
    final raw = data['availableFilters'];
    if (raw is List) {
      final parsed = raw
          .whereType<Map<String, dynamic>>()
          .map(RecommendationFilterOption.fromJson)
          .where((e) => e.apiPreference.trim().isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final hasSweet = products.any((p) => p.category == ProductCategory.sweet);
    final hasSavory = products.any((p) => p.category == ProductCategory.savory);
    final hasDrink = products.any((p) => p.category == ProductCategory.drink);
    final hasBakery = products.any((p) => p.category == ProductCategory.bakery);

    final generatedFilters = <RecommendationFilterOption>[
      if (hasSweet)
        const RecommendationFilterOption(
          id: 'sweet',
          label: 'Tatlı',
          apiPreference: 'any',
        ),
      if (hasSavory)
        const RecommendationFilterOption(
          id: 'savory',
          label: 'Tuzlu',
          apiPreference: 'savory',
        ),
      if (hasBakery)
        const RecommendationFilterOption(
          id: 'bakery',
          label: 'Kahvaltılık',
          apiPreference: 'bakery',
        ),
      if (hasDrink)
        const RecommendationFilterOption(
          id: 'drink',
          label: 'İçecek',
          apiPreference: 'drink',
        ),
    ];

    return generatedFilters.isNotEmpty ? generatedFilters : _defaultFilters();
  }

  List<RecommendationFilterOption> _defaultFilters() {
    return const <RecommendationFilterOption>[
      RecommendationFilterOption(id: 'sweet', label: 'Tatlı', apiPreference: 'any'),
      RecommendationFilterOption(id: 'chocolate', label: 'Çikolatalı', apiPreference: 'chocolate'),
      RecommendationFilterOption(id: 'fruit', label: 'Meyveli', apiPreference: 'fruit'),
      RecommendationFilterOption(id: 'bakery', label: 'Kahvaltılık', apiPreference: 'bakery'),
      RecommendationFilterOption(id: 'drink', label: 'İçecek', apiPreference: 'drink'),
    ];
  }

  void _logRecommendationDebug({
    required String preference,
    required String appliedFilter,
    required List<String> excludedProductNames,
    required List<RecommendationItem> finalProducts,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[RECO] selected preference: $preference');
    debugPrint('[RECO] applied category filter: $appliedFilter');
    debugPrint('[RECO] excluded products: ${excludedProductNames.join(', ')}');
    debugPrint(
      '[RECO] final scored list: ${finalProducts.map((e) => '${e.name}:${e.score.toStringAsFixed(2)}').join(' | ')}',
    );
  }
}
