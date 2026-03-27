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

  void resetGame() {
    patternLines = List.generate(5, (index) => []);
    wallState = List.generate(5, (i) => List.filled(5, false));
    shatterLine = [];
    score = 0;
    bonusTrackers = {'rows': 0, 'columns': 0, 'colors': 0};
    gameStatus = 'drafting';
    notifyListeners();
  }
}