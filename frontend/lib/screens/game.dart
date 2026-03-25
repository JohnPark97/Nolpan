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
  late List<List<String>> factories;
  late List<String> center;
  late Map<String, dynamic> boards;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _updateState(widget.initialState);
    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'GAME_UPDATE') { setState(() { _updateState(msg['payload']); }); }
    });
  }

  void _updateState(Map<String, dynamic> payload) {
    factories = (payload['factories'] as List).map((f) => List<String>.from(f)).toList();
    center = List<String>.from(payload['center'] ?? []);
    boards = payload['boards'] ?? {};
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  // --- UI COMPONENTS ---
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
    if (empty) return Container(width: 20, height: 20, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)));
    return Container(
      width: 20, height: 20, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isGhost ? bg.withOpacity(0.15) : bg, borderRadius: BorderRadius.circular(4),
        border: Border(bottom: BorderSide(color: isGhost ? Colors.transparent : shadow, width: 2.5)),
      ),
      child: Center(child: Icon(icon, size: 10, color: Colors.white.withOpacity(0.5))),
    );
  }

  Widget _buildOpponentRow(String name, Map<String, dynamic> board) {
    List wall = board['wall'] ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: tTeal, child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white))),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          // Mini Wall Heatmap
          Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) {
            String tile = wall.isNotEmpty ? wall[r][c] : "";
            return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4, decoration: BoxDecoration(color: tile == "" ? Colors.grey[200] : tTeal, borderRadius: BorderRadius.circular(1)));
          })))),
          const SizedBox(width: 12),
          Text("${board['score'] ?? 0}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: tInk)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "Player";
    Map<String, dynamic> myBoard = boards[myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? List.generate(5, (i) => List.filled(i + 1, ""));
    List wall = myBoard['wall'] ?? List.generate(5, (_) => List.filled(5, ""));
    List floor = myBoard['floor_line'] ?? [];
    List<String> opponents = boards.keys.where((k) => k != myName).toList();

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER & TINY TEST WIN BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("DRAFTING PHASE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: tInk.withOpacity(0.5))),
                  IconButton(
                    icon: const Icon(Icons.emoji_events_outlined, color: tGold, size: 20),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen())),
                  ),
                ],
              ),
            ),
            
            // ZONE 1: OPPONENTS (30%)
            Expanded(flex: 3, child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: ListView(children: opponents.map((opp) => _buildOpponentRow(opp, boards[opp])).toList()),
            )),
            
            // ZONE 2: MARKET (30%)
            Expanded(flex: 3, child: Container(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                children: factories.map((f) => Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Center(child: Wrap(children: f.map((t) => _buildPhysicsTile(t)).toList())),
                )).toList(),
              ),
            )),
            
            // ZONE 3: PLAYER WORKSHOP (40%)
            Expanded(flex: 4, child: Container(
              color: Colors.white, padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                  ]),
                  const SizedBox(height: 12),
                  // PATTERN & WALL ROW
                  Expanded(child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // PATTERN LINES (Left)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(5, (r) => Row(children: List.generate(r + 1, (c) => _buildPhysicsTile(patternLines[r][c], empty: patternLines[r][c] == ""))))),
                      const SizedBox(width: 16),
                      // THE WALL (Right)
                      Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) {
                        String t = wall[r][c];
                        return t != "" ? _buildPhysicsTile(t) : _buildPhysicsTile(wallPattern[r][c], isGhost: true);
                      })))),
                    ],
                  )),
                  // SHATTER LINE
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(7, (i) => _buildPhysicsTile(i < floor.length ? floor[i] : "", empty: i >= floor.length))),
                  const SizedBox(height: 12),
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