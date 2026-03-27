class GameState {
  final List<List<String>> factories;
  final List<String> centerPool;
  final int currentTurn;

  GameState({
    required this.factories,
    required this.centerPool,
    required this.currentTurn,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      factories: (json['factories'] as List)
          .map((f) => List<String>.from(f))
          .toList(),
      centerPool: List<String>.from(json['center_pool']),
      currentTurn: json['current_turn'],
    );
  }

  void resetGame() {
    // Arrays reset logic per spec
  }
}