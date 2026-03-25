import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';
import 'victory.dart';

const List<List<String>> wallPattern = [
  ['blue', 'yellow', 'red', 'black', 'white'],
  ['white', 'blue', 'yellow', 'red', 'black'],
  ['black', 'white', 'blue', 'yellow', 'red'],
  ['red', 'black', 'white', 'blue', 'yellow'],
  ['yellow', 'red', 'black', 'white', 'blue'],
];

class GameScreen extends StatefulWidget {
  final Map<String, dynamic> initialState;
  const GameScreen({super.key, required this.initialState});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<List<String>>? factories;
  List<String>? center;
  Map<String, dynamic>? boards;
  String? turnPlayer;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _updateState(widget.initialState);
    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'GAME_UPDATE' || msg['type'] == 'GAME_STARTED') {
        if (mounted) setState(() { _updateState(msg['payload']); });
      }
    });
  }

  void _updateState(Map<String, dynamic> payload) {
    // THE FIX: Robust data mapping to prevent null/empty crashes
    if (payload['factories'] != null) {
      factories = (payload['factories'] as List).map((f) => List<String>.from(f)).toList();
    }
    center = List<String>.from(payload['center'] ?? []);
    boards = Map<String, dynamic>.from(payload['boards'] ?? {});
    
    // Explicit turn player from backend or first available key safely
    turnPlayer = payload['turn_player'] ?? (boards!.isNotEmpty ? boards!.keys.first : "...");
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  Widget _buildPhysicsTile(String colorName, {bool empty = false, bool isGhost = false}) {
    Color bg; IconData? icon; Color shadow = Colors.transparent;
    switch (colorName) {
      case 'blue': bg = tTeal; icon = Icons.star; shadow = const Color(0xFF1A695F); break;
      case 'red': bg = tTerra; icon = Icons.menu; shadow = const Color(0xFFA84128); break;
      case 'yellow': bg = tGold; icon = Icons.circle; shadow = const Color(0xFFC9A24A); break;
      case 'black': bg = tInk; icon = Icons.close; shadow = const Color(0xFF11121A); break;
      case 'white': bg = tIce; icon = Icons.square_outlined; shadow = Colors.grey[300]!; break;
      default: bg = Colors.transparent;
    }
    if (empty) return Container(width: 20, height: 20, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)));
    return Container(
      width: 20, height: 20, margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: isGhost ? bg.withOpacity(0.15) : bg, borderRadius: BorderRadius.circular(4),
        border: Border(bottom: BorderSide(color: isGhost ? Colors.transparent : shadow, width: 2.5)),
      ),
      child: Center(child: Icon(icon, size: 10, color: Colors.white.withOpacity(0.5))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // THE SAFETY GATE: If data is null, show loading instead of grey screen
    if (factories == null || boards == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: tTeal)));
    }

    String myName = socketService.playerName ?? "Player";
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    List<String> opponents = boards!.keys.where((k) => k != myName).toList();

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER & MINI TEST WIN
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("TURN: ${turnPlayer?.toUpperCase()}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)),
                  IconButton(icon: const Icon(Icons.emoji_events, color: tGold, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen()))),
                ],
              ),
            ),
            
            // ZONE 1: OPPONENTS
            Expanded(flex: 3, child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: opponents.isEmpty 
                ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, color: Colors.grey)))
                : ListView(children: opponents.map((opp) {
                    var oppBoard = boards![opp];
                    return Row(children: [
                      CircleAvatar(radius: 12, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Text("Score: ${oppBoard['score']}", style: const TextStyle(fontSize: 12)),
                    ]);
                  }).toList()),
            )),

            // ZONE 2: MARKET
            Expanded(flex: 3, child: Wrap(
              alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
              children: factories!.map((f) => Container(
                width: 60, height: 60, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(child: Wrap(children: f.map((t) => _buildPhysicsTile(t)).toList())),
              )).toList(),
            )),

            // ZONE 3: PLAYER WORKSHOP (RESTORED ALIGNMENT)
            Expanded(flex: 4, child: Container(
              color: Colors.white, padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                  ]),
                  const SizedBox(height: 12),
                  // Pattern & Wall Grid
                  Expanded(child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(5, (r) => Row(children: List.generate(r + 1, (c) => _buildPhysicsTile(patternLines.isNotEmpty ? patternLines[r][c] : "", empty: true))))),
                      const SizedBox(width: 24),
                      Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) {
                        String t = wall.isNotEmpty ? wall[r][c] : "";
                        return t != "" ? _buildPhysicsTile(t) : _buildPhysicsTile(wallPattern[r][c], isGhost: true);
                      } )))),
                    ],
                  )),
                  PhysicsButton(text: "SET MOSAIC", color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: () {}),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}