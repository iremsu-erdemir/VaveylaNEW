import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/recommendations_service.dart';

abstract class RecommendationChatService {
  Future<RecommendationResult> fetchRecommendations({
    required String preference,
  });
}

class ApiRecommendationChatService implements RecommendationChatService {
  ApiRecommendationChatService({RecommendationsService? recommendationsService})
      : _recommendationsService = recommendationsService ?? RecommendationsService();

  final RecommendationsService _recommendationsService;

  @override
  Future<RecommendationResult> fetchRecommendations({
    required String preference,
  }) {
    return _recommendationsService.getRecommendationResult(preference: preference);
  }
}
