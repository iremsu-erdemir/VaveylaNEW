import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/recommendation_chat_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_state.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_state_machine.dart';

class RecommendationChatController extends Cubit<RecommendationChatState> {
  RecommendationChatController({
    RecommendationChatService? chatService,
    RecommendationChatStateMachine? stateMachine,
    Duration? thinkingDelay,
  }) : _chatService = chatService ?? ApiRecommendationChatService(),
       _stateMachine = stateMachine ?? const RecommendationChatStateMachine(),
       _thinkingDelay = thinkingDelay ?? const Duration(milliseconds: 240),
        super(RecommendationChatState.initial());

  final RecommendationChatService _chatService;
  final RecommendationChatStateMachine _stateMachine;
  final Duration _thinkingDelay;

  void clearSnackError() {
    emit(_stateMachine.transition(state, const SnackErrorCleared()));
  }

  Future<void> selectPreference(String label, String apiPreference) async {
    if (state.awaitingResponse) {
      return;
    }

    emit(
      _stateMachine.transition(
        state,
        UserChoiceSubmitted(label: label, preference: apiPreference),
      ),
    );

    await Future<void>.delayed(_thinkingDelay);

    emit(_stateMachine.transition(state, const ThinkingStarted()));

    try {
      final result = await _chatService.fetchRecommendations(preference: apiPreference);
      emit(_stateMachine.transition(state, RecommendationsLoaded(result)));
    } catch (e) {
      emit(_stateMachine.transition(state, RecommendationsFailed(e)));
    }
  }
}
