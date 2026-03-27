// Placeholder updated game_state.dart
class GameState extends ChangeNotifier {
  final List<String> tileColors = ['Red', 'Blue', 'Yellow', 'Black', 'Amethyst'];
  String gameStatus = 'drafting';

  void resetGame() {
    // hard wipe arrays
    gameStatus = 'drafting';
    notifyListeners();
    SocketService.broadcastStateReset(roomId);
  }
}