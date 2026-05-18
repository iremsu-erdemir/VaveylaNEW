import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_state.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_state_machine.dart';

RecommendationItem _item() => const RecommendationItem(
      id: 'r1',
      restaurantId: 'rest-1',
      restaurantName: 'Tatli Dunyasi',
      name: 'Trilece',
      shortDescription: 'Hafif sutlu tatli',
      imagePath: '/img/trilece.png',
      price: 95,
      saleUnit: 1,
      score: 4.7,
      reason: 'Hafif tercihine uygun.',
      category: ProductCategory.sweet,
      subcategory: 'milk',
      tags: <String>['light'],
      isActive: true,
    );

void main() {
  group('RecommendationChatStateMachine', () {
    const stateMachine = RecommendationChatStateMachine();

    test('transitions to thinking after user choice and thinking start', () {
      var state = RecommendationChatState.initial();
      state = stateMachine.transition(
        state,
        const UserChoiceSubmitted(label: 'Hafif', preference: 'light'),
      );
      state = stateMachine.transition(state, const ThinkingStarted());

      expect(state.phase, RecommendationChatPhase.thinking);
      expect(state.awaitingResponse, isTrue);
      expect(state.messages.last.loading, isTrue);
    });

    test('transitions to showingResult on loaded recommendations', () {
      var state = RecommendationChatState.initial();
      state = stateMachine.transition(
        state,
        const UserChoiceSubmitted(label: 'Any', preference: 'any'),
      );
      state = stateMachine.transition(state, const ThinkingStarted());
      state = stateMachine.transition(
        state,
        RecommendationsLoaded(
          RecommendationResult(
            products: <RecommendationItem>[_item()],
            appliedFilter: 'sweet/any',
            excludedProducts: <String>[],
            reason: 'ok',
            availableFilters: <RecommendationFilterOption>[],
          ),
        ),
      );

      expect(state.phase, RecommendationChatPhase.showingResult);
      expect(state.awaitingResponse, isFalse);
    });
  });
}
