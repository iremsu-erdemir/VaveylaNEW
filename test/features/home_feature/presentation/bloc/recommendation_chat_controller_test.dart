import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/recommendation_chat_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_controller.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_state.dart';

class _FakeRecommendationChatService implements RecommendationChatService {
  _FakeRecommendationChatService({
    this.result = const RecommendationResult(
      products: <RecommendationItem>[],
      appliedFilter: 'sweet/any',
      excludedProducts: <String>[],
      reason: '',
      availableFilters: <RecommendationFilterOption>[],
    ),
    this.error,
  });

  final RecommendationResult result;
  final Object? error;

  @override
  Future<RecommendationResult> fetchRecommendations({
    required String preference,
  }) async {
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

RecommendationItem _sampleItem() {
  return const RecommendationItem(
    id: '1',
    restaurantId: 'rest-1',
    restaurantName: 'Tatli Dunyasi',
    name: 'Cikolatali Pasta',
    shortDescription: 'Yumusak kek ve ganaj',
    imagePath: '/img/pasta.png',
    price: 120,
    saleUnit: 1,
    score: 4.8,
    reason: 'Tatli krizin icin ideal.',
    category: ProductCategory.sweet,
    subcategory: 'chocolate',
    tags: <String>['chocolate'],
    isActive: true,
  );
}

void main() {
  group('RecommendationChatController', () {
    test('initial state is awaitingUserChoice', () {
      final controller = RecommendationChatController(
        chatService: _FakeRecommendationChatService(),
        thinkingDelay: Duration.zero,
      );

      expect(controller.state.phase, RecommendationChatPhase.awaitingUserChoice);
      expect(controller.state.showQuickReplies, isTrue);
      expect(controller.state.messages, isNotEmpty);

      controller.close();
    });

    test('selectPreference transitions to showingResult on success', () async {
      final emitted = <RecommendationChatState>[];
      final controller = RecommendationChatController(
        chatService: _FakeRecommendationChatService(
          result: RecommendationResult(
            products: <RecommendationItem>[_sampleItem()],
            appliedFilter: 'sweet/chocolate',
            excludedProducts: const <String>['Simit'],
            reason: 'hard filter',
            availableFilters: const <RecommendationFilterOption>[
              RecommendationFilterOption(
                id: 'chocolate',
                label: 'Cikolatali',
                apiPreference: 'chocolate',
              ),
            ],
          ),
        ),
        thinkingDelay: Duration.zero,
      );
      final sub = controller.stream.listen(emitted.add);

      await controller.selectPreference('Cikolatali', 'chocolate');

      expect(emitted, isNotEmpty);
      expect(
        emitted.any((state) => state.phase == RecommendationChatPhase.thinking),
        isTrue,
      );
      expect(controller.state.phase, RecommendationChatPhase.showingResult);
      expect(controller.state.messages.last.recommendations, isNotEmpty);

      await sub.cancel();
      await controller.close();
    });

    test('selectPreference transitions to error on service failure', () async {
      final controller = RecommendationChatController(
        chatService: _FakeRecommendationChatService(error: Exception('network')),
        thinkingDelay: Duration.zero,
      );

      await controller.selectPreference('Meyveli', 'fruit');

      expect(controller.state.phase, RecommendationChatPhase.error);
      expect(controller.state.pendingSnackError, isNotNull);

      await controller.close();
    });
  });
}
