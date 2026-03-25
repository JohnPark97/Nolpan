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
  
  String? selectedColor;
  int? selectedKiln;

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
    factories = (payload['factories'] as List).map((f) => List<String>.from(f)).toList();
    center = List<String>.from(payload['center'] ?? []);
    boards = Map<String, dynamic>.from(payload['boards'] ?? {});
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  // --- COMPONENT: TACTILE TILE ---
  Widget _buildPhysicsTile(String colorName, {bool empty = false, bool isGhost = false, bool isSelected = false, VoidCallback? onTap}) {
    Color bg; IconData? icon; Color shadow = Colors.transparent;
    switch (colorName) {
      case 'blue': bg = tTeal; icon = Icons.star; shadow = const Color(0xFF1A695F); break;
      case 'red': bg = tTerra; icon = Icons.menu; shadow = const Color(0xFFA84128); break;
      case 'yellow': bg = tGold; icon = Icons.circle; shadow = const Color(0xFFC9A24A); break;
      case 'black': bg = tInk; icon = Icons.close; shadow = const Color(0xFF11121A); break;
      case 'white': bg = tIce; icon = Icons.square_outlined; shadow = Colors.grey[300]!; break;
      default: bg = Colors.transparent;
    }

    Widget tile = Container(
      width: 22, height: 22, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isGhost ? bg.withOpacity(0.1) : bg,
        borderRadius: BorderRadius.circular(4),
        border: isSelected ? Border.all(color: tInk, width: 2) : (isGhost ? Border.all(color: bg.withOpacity(0.2)) : null),
        boxShadow: (isGhost || empty) ? [] : [BoxShadow(color: shadow, offset: const Offset(0, 2))],
      ),
      child: empty ? null : Center(child: Icon(icon, size: 10, color: Colors.white.withOpacity(0.5))),
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: tile) : tile;
  }

  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "Player";
    Map<String, dynamic> myBoard = boards[myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    List<String> opponents = boards.keys.where((k) => k != myName).toList();

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(
          children: [
            // ZONE 1: OPPONENTS (flex: 3)
            Expanded(flex: 3, child: Container(
              width: double.infinity, margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: opponents.isEmpty 
                ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))
                : ListView(children: opponents.map((opp) {
                    var oppBoard = boards[opp];
                    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                      CircleAvatar(radius: 12, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) => Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4, decoration: BoxDecoration(color: (oppBoard['wall'] != null && oppBoard['wall'][r][c] != "") ? tTeal : Colors.grey[200])))))),
                      const SizedBox(width: 12),
                      Text("${oppBoard['score']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ]));
                  }).toList()),
            )),

            // ZONE 2: MARKET (flex: 3)
            Expanded(flex: 3, child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                  children: List.generate(factories.length, (kilnIdx) => Container(
                    width: 60, height: 60,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Center(child: Wrap(children: factories[kilnIdx].map((tileColor) => _buildPhysicsTile(
                      tileColor, 
                      isSelected: selectedKiln == kilnIdx && selectedColor == tileColor,
                      onTap: () => setState(() { selectedKiln = kilnIdx; selectedColor = tileColor; }),
                    )).toList())),
                  )),
                ),
                const SizedBox(height: 12),
                // Center Pool
                Container(
                  height: 36, width: 200, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(18)),
                  child: Center(child: center.isEmpty ? const Text("CENTER", style: TextStyle(fontSize: 10, color: Colors.grey)) : Wrap(children: center.map((t) => _buildPhysicsTile(t)).toList())),
                )
              ],
            )),

            // ZONE 3: WORKSHOP (flex: 4)
            Expanded(flex: 4, child: Container(
              color: Colors.white, padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    IconButton(icon: const Icon(Icons.emoji_events_outlined, color: tGold, size: 18), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen()))),
                    Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tTeal)),
                  ]),
                  // STAIRCASE AND WALL GRID
                  Expanded(child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pattern Lines
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(5, (r) => Row(children: List.generate(r + 1, (c) {
                        String t = (patternLines.length > r && patternLines[r].length > c) ? patternLines[r][c] : "";
                        return _buildPhysicsTile(t, empty: t == "");
                      } )))),
                      const SizedBox(width: 20),
                      // Wall
                      Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) {
                        String t = (wall.length > r && wall[r].length > c) ? wall[r][c] : "";
                        return t != "" ? _buildPhysicsTile(t) : _buildPhysicsTile(wallPattern[r][c], isGhost: true);
                      } )))),
                    ],
                  )),
                  // Floor Line
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(7, (i) {
                    String t = i < floor.length ? floor[i] : "";
                    return _buildPhysicsTile(t, empty: t == "");
                  })),
                  const SizedBox(height: 12),
                  PhysicsButton(
                    text: selectedColor != null ? "PLACE ${selectedColor!.toUpperCase()}" : "SELECT TILES",
                    color: selectedColor != null ? tTeal : Colors.grey[400]!,
                    shadowColor: selectedColor != null ? const Color(0xFF1A695F) : Colors.grey[500]!,
                    onTap: () {
                      if (selectedColor != null) {
                        // TODO: Send Pick event to server
                        setState(() { selectedColor = null; selectedKiln = null; });
                      }
                    },
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}