import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../main.dart';
import 'victory.dart';

class GameScreen extends StatefulWidget {
  final Map<String, dynamic> initialState;
  const GameScreen({super.key, required this.initialState});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<List<String>> factories;
  late Map<String, dynamic> boards;
  final List<List<GlobalKey>> patternKeys = List.generate(5, (r) => List.generate(r + 1, (c) => GlobalKey()));
  final List<List<GlobalKey>> wallKeys = List.generate(5, (r) => List.generate(5, (c) => GlobalKey()));

  @override
  void initState() {
    super.initState();
    _updateState(widget.initialState);
    socketService.stream.listen((message) {
      if (message['type'] == 'GAME_UPDATE') { setState(() { _updateState(message['payload']); }); }
    });
  }

  void _updateState(Map<String, dynamic> payload) {
    factories = (payload['factories'] as List).map((f) => List<String>.from(f)).toList();
    boards = payload['boards'] ?? {};
  }

  Widget _buildPhysicsTile(String colorName, {bool empty = false, bool isGhost = false, GlobalKey? key}) {
    Color bg; IconData? icon; Color shadow = Colors.transparent;
    switch (colorName) {
      case 'blue': bg = tTeal; icon = Icons.star; shadow = const Color(0xFF1A695F); break;
      case 'red': bg = tTerra; icon = Icons.menu; shadow = const Color(0xFFA84128); break;
      case 'yellow': bg = tGold; icon = Icons.circle; shadow = const Color(0xFFC9A24A); break;
      case 'black': bg = tInk; icon = Icons.close; shadow = const Color(0xFF11121A); break;
      case 'white': bg = tIce; icon = Icons.square_outlined; shadow = Colors.grey[300]!; break;
      default: bg = Colors.transparent;
    }
    if (empty) return Container(key: key, width: 24, height: 24, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)));
    return Container(key: key, width: 24, height: 24, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: isGhost ? bg.withOpacity(0.2) : bg, borderRadius: BorderRadius.circular(4), border: Border(bottom: BorderSide(color: isGhost ? Colors.transparent : shadow, width: 3))), child: Center(child: Icon(icon, size: 12, color: Colors.white.withOpacity(0.5))));
  }

  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "Player";
    var board = boards[myName] ?? {};
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(children: [
          Expanded(flex: 3, child: Container(color: Colors.white, child: const Center(child: Text("OPPONENTS")))),
          Expanded(flex: 3, child: Wrap(alignment: WrapAlignment.center, children: factories.map((f) => Container(width: 60, height: 60, margin: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: Wrap(children: f.map((t) => _buildPhysicsTile(t)).toList())) )).toList())),
          Expanded(flex: 4, child: Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Colors.white), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(myName, style: const TextStyle(fontWeight: FontWeight.bold)), Text("SCORE: ${board['score'] ?? 0}")]),
            const Spacer(),
            PhysicsButton(text: "TEST WIN", color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen())))
          ])))
        ]),
      ),
    );
  }
}