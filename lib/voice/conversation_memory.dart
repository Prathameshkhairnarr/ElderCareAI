/// In-memory conversation history for contextual AI responses.
///
/// Stores the last [maxTurns] conversation turns (user + assistant pairs).
/// Used to give the LLM context about recent conversation flow.
///
/// Privacy-safe: no persistence — clears on app restart.
/// Thread-safe: single-isolate Flutter app, no locking needed.
class ConversationMemory {
  ConversationMemory._();
  static final ConversationMemory instance = ConversationMemory._();

  /// Maximum conversation turns to remember.
  static const int maxTurns = 5;

  final List<ConversationTurn> _turns = [];

  /// All stored turns (read-only view).
  List<ConversationTurn> get turns => List.unmodifiable(_turns);

  /// Number of stored turns.
  int get length => _turns.length;

  /// Whether any history exists.
  bool get hasHistory => _turns.isNotEmpty;

  /// Add a new conversation turn.
  void addTurn(String userText, String assistantResponse) {
    _turns.add(
      ConversationTurn(
        userText: userText,
        assistantResponse: assistantResponse,
        timestamp: DateTime.now(),
      ),
    );

    // Enforce circular buffer
    while (_turns.length > maxTurns) {
      _turns.removeAt(0);
    }
  }

  /// Format conversation history for LLM context injection.
  ///
  /// Returns a compact multi-line string:
  /// ```
  /// User: mera health score batao
  /// Assistant: Aapki health ki jaankari...
  /// User: risk kitna hai
  /// Assistant: Aapka risk score...
  /// ```
  String getFormattedHistory() {
    if (_turns.isEmpty) return '';

    final buffer = StringBuffer();
    for (final turn in _turns) {
      buffer.writeln('User: ${turn.userText}');
      buffer.writeln('Assistant: ${turn.assistantResponse}');
    }
    return buffer.toString().trim();
  }

  /// Get the last user query, or null if no history.
  String? get lastUserQuery => _turns.isNotEmpty ? _turns.last.userText : null;

  /// Get the last assistant response, or null if no history.
  String? get lastAssistantResponse =>
      _turns.isNotEmpty ? _turns.last.assistantResponse : null;

  /// Clear all conversation history.
  void clear() => _turns.clear();
}

/// A single conversation turn (user input + assistant response).
class ConversationTurn {
  final String userText;
  final String assistantResponse;
  final DateTime timestamp;

  const ConversationTurn({
    required this.userText,
    required this.assistantResponse,
    required this.timestamp,
  });

  @override
  String toString() =>
      'ConversationTurn(user="$userText", assistant="${assistantResponse.length > 50 ? '${assistantResponse.substring(0, 50)}...' : assistantResponse}")';
}
