import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_state.dart';

sealed class RecommendationChatEvent {
  const RecommendationChatEvent();
}

class UserChoiceSubmitted extends RecommendationChatEvent {
  const UserChoiceSubmitted({
    required this.label,
    required this.preference,
  });

  final String label;
  final String preference;
}

class ThinkingStarted extends RecommendationChatEvent {
  const ThinkingStarted();
}

class RecommendationsLoaded extends RecommendationChatEvent {
  const RecommendationsLoaded(this.result);

  final RecommendationResult result;
}

class RecommendationsFailed extends RecommendationChatEvent {
  const RecommendationsFailed(this.error);

  final Object error;
}

class SnackErrorCleared extends RecommendationChatEvent {
  const SnackErrorCleared();
}

class RecommendationChatStateMachine {
  const RecommendationChatStateMachine();

  RecommendationChatState transition(
    RecommendationChatState current,
    RecommendationChatEvent event,
  ) {
    return switch (event) {
      UserChoiceSubmitted() => _onUserChoiceSubmitted(current, event),
      ThinkingStarted() => _onThinkingStarted(current),
      RecommendationsLoaded() => _onRecommendationsLoaded(current, event.result),
      RecommendationsFailed() => _onRecommendationsFailed(current, event.error),
      SnackErrorCleared() => _onSnackErrorCleared(current),
    };
  }

  RecommendationChatState _onUserChoiceSubmitted(
    RecommendationChatState current,
    UserChoiceSubmitted event,
  ) {
    final selectedMessages = <RecommendationChatMessage>[
      ...current.messages,
      RecommendationChatMessage(fromUser: true, text: event.label),
      RecommendationChatMessage(
        fromUser: false,
        text: 'Harika seçim! Senin için en uygun önerileri hazırlıyorum 🍰',
      ),
    ];

    return current.copyWith(
      messages: selectedMessages,
      showQuickReplies: true,
      awaitingResponse: true,
      phase: RecommendationChatPhase.idle,
      selectedLabel: event.label,
      selectedPreference: event.preference,
      pendingSnackError: null,
    );
  }

  RecommendationChatState _onThinkingStarted(RecommendationChatState current) {
    final messages = <RecommendationChatMessage>[
      ..._withoutLoadingMessage(current.messages),
      RecommendationChatMessage(fromUser: false, loading: true),
    ];
    return current.copyWith(
      messages: messages,
      showQuickReplies: true,
      awaitingResponse: true,
      phase: RecommendationChatPhase.thinking,
      pendingSnackError: null,
    );
  }

  RecommendationChatState _onRecommendationsLoaded(
    RecommendationChatState current,
    RecommendationResult result,
  ) {
    final items = result.products;
    final withoutLoading = _withoutLoadingMessage(current.messages);
    if (items.isEmpty) {
      return current.copyWith(
        messages: <RecommendationChatMessage>[
          ...withoutLoading,
          RecommendationChatMessage(
            fromUser: false,
            text: 'Bu kategori için öneri bulunamadı.',
          ),
        ],
        showQuickReplies: true,
        awaitingResponse: false,
        phase: RecommendationChatPhase.error,
        appliedFilter: result.appliedFilter,
        responseReason: result.reason,
        availableFilters: result.availableFilters,
        pendingSnackError: null,
      );
    }

    return current.copyWith(
      messages: <RecommendationChatMessage>[
        ...withoutLoading,
        RecommendationChatMessage(
          fromUser: false,
          text: 'Harika seçim! Bugün için önerilerim:',
        ),
        RecommendationChatMessage(fromUser: false, recommendations: items),
      ],
      showQuickReplies: true,
      awaitingResponse: false,
      phase: RecommendationChatPhase.showingResult,
      appliedFilter: result.appliedFilter,
      responseReason: result.reason,
      availableFilters: result.availableFilters,
      pendingSnackError: null,
    );
  }

  RecommendationChatState _onRecommendationsFailed(
    RecommendationChatState current,
    Object error,
  ) {
    final withoutLoading = _withoutLoadingMessage(current.messages);
    return current.copyWith(
      messages: <RecommendationChatMessage>[
        ...withoutLoading,
        RecommendationChatMessage(
          fromUser: false,
          text: 'Önerileri alırken bir sorun oluştu. Biraz sonra tekrar dene.',
        ),
      ],
      showQuickReplies: true,
      awaitingResponse: false,
      phase: RecommendationChatPhase.error,
      pendingSnackError: error,
    );
  }

  RecommendationChatState _onSnackErrorCleared(RecommendationChatState current) {
    if (current.pendingSnackError == null) {
      return current;
    }
    return current.copyWith(pendingSnackError: null);
  }

  List<RecommendationChatMessage> _withoutLoadingMessage(
    List<RecommendationChatMessage> messages,
  ) {
    if (messages.isEmpty || !messages.last.loading) {
      return messages;
    }
    return messages.sublist(0, messages.length - 1);
  }
}
