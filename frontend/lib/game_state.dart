class GameState {
  final List> factories;
  final List centerPool;
  final int currentTurn;

  GameState({
    required this.factories,
    required this.centerPool,
    required this.currentTurn,
  });

  factory GameState.fromJson(Map json) {
    return GameState(
      factories: (json['factories'] as List)
          .map((f) => List.from(f))
          .toList(),
      centerPool: List.from(json['center_pool']),
      currentTurn: json['current_turn'],
    );
  }
}