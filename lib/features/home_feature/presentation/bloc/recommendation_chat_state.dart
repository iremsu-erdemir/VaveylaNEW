import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';

enum RecommendationChatPhase {
  idle,
  awaitingUserChoice,
  thinking,
  showingResult,
  error,
}

class RecommendationChatMessage {
  RecommendationChatMessage({
    String? id,
    required this.fromUser,
    this.text,
    this.recommendations,
    this.loading = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final bool fromUser;
  final String? text;
  final List<RecommendationItem>? recommendations;
  final bool loading;
}

class RecommendationChatState {
  const RecommendationChatState({
    required this.messages,
    required this.showQuickReplies,
    required this.awaitingResponse,
    required this.phase,
    this.selectedLabel,
    this.selectedPreference = 'any',
    this.appliedFilter,
    this.responseReason,
    this.availableFilters = const <RecommendationFilterOption>[],
    this.pendingSnackError,
  });

  static final RecommendationChatMessage initialGreeting = RecommendationChatMessage(
    fromUser: false,
    text: 'Merhaba 👋 Bugün sana özel bir tatlı seçelim',
  );

  factory RecommendationChatState.initial() => RecommendationChatState(
        messages: <RecommendationChatMessage>[initialGreeting],
        showQuickReplies: true,
        awaitingResponse: false,
        phase: RecommendationChatPhase.awaitingUserChoice,
      );

  final List<RecommendationChatMessage> messages;
  final bool showQuickReplies;
  final bool awaitingResponse;
  final RecommendationChatPhase phase;
  final String? selectedLabel;
  final String selectedPreference;
  final String? appliedFilter;
  final String? responseReason;
  final List<RecommendationFilterOption> availableFilters;
  final Object? pendingSnackError;

  bool get isAnySelection => selectedPreference == 'any';

  RecommendationChatState copyWith({
    List<RecommendationChatMessage>? messages,
    bool? showQuickReplies,
    bool? awaitingResponse,
    RecommendationChatPhase? phase,
    String? selectedLabel,
    String? selectedPreference,
    String? appliedFilter,
    String? responseReason,
    List<RecommendationFilterOption>? availableFilters,
    Object? pendingSnackError = _undefined,
  }) {
    return RecommendationChatState(
      messages: messages ?? this.messages,
      showQuickReplies: showQuickReplies ?? this.showQuickReplies,
      awaitingResponse: awaitingResponse ?? this.awaitingResponse,
      phase: phase ?? this.phase,
      selectedLabel: selectedLabel ?? this.selectedLabel,
      selectedPreference: selectedPreference ?? this.selectedPreference,
      appliedFilter: appliedFilter ?? this.appliedFilter,
      responseReason: responseReason ?? this.responseReason,
      availableFilters: availableFilters ?? this.availableFilters,
      pendingSnackError:
          identical(pendingSnackError, _undefined) ? this.pendingSnackError : pendingSnackError,
    );
  }
}

const Object _undefined = Object();
