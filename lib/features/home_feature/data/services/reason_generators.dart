import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';

abstract class IReasonGenerator {
  String generate({
    required RecommendationItem item,
    required String preference,
  });
}

class RuleBasedReasonGenerator implements IReasonGenerator {
  const RuleBasedReasonGenerator();

  @override
  String generate({
    required RecommendationItem item,
    required String preference,
  }) {
    final existing = item.reason.trim();
    if (existing.isNotEmpty) {
      return existing;
    }

    final normalizedPreference = preference.toLowerCase().trim();
    if (normalizedPreference == 'any') {
      return '${item.name}, menüdeki en sevilen seçeneklerden biri.';
    }
    return '${item.name}, "$normalizedPreference" tercihine uygun bir seçenek.';
  }
}

class LLMReasonGenerator implements IReasonGenerator {
  const LLMReasonGenerator();

  @override
  String generate({
    required RecommendationItem item,
    required String preference,
  }) {
    // Future-ready stub: LLM integration will live here.
    return '';
  }
}
