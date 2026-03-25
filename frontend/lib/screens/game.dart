import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';

// DESIGN TOKENS
const Color tTeal = Color(0xFF2A9D8F);
const Color tTerra = Color(0xFFE76F51);
const Color tGold = Color(0xFFE9C46A);
const Color tInk = Color(0xFF2B2D42);
const Color tIce = Color(0xFFE0E5EC);
const Color tBg = Color(0xFFF9F7F3);

// AZUL STANDARD WALL PATTERN (Diagonal Shift)
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
    _sub = socketService.stream.listen((message) {
      if (message['type'] == 'GAME_STARTED' || message['type'] == 'GAME_UPDATE') {
        if (mounted) setState(() { _updateState(message['payload']); });
      }
    });
  }

  void _updateState(Map<String, dynamic> payload) {
    factories = (payload['factories'] as List).map((f) => List<String>.from(f)).toList();
    center = List<String>.from(payload['center'] ?? []);
    boards = payload['boards'] ?? {};
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  // --- COMPONENT: PHYSICS TILE ---
  Widget _buildPhysicsTile(String colorName, {bool empty = false, bool isGhost = false}) {
    Color bg; IconData? icon; Color iconColor = Colors.white; Color shadow = Colors.transparent;

    switch (colorName) {
      case 'blue': bg = tTeal; icon = Icons.star_rounded; shadow = const Color(0xFF1A695F); break;
      case 'red': bg = tTerra; icon = Icons.menu; shadow = const Color(0xFFA84128); break;
      case 'yellow': bg = tGold; icon = Icons.circle; shadow = const Color(0xFFC9A24A); break;
      case 'black': bg = tInk; icon = Icons.close; shadow = const Color(0xFF11121A); break;
      case 'white': bg = tIce; icon = Icons.check_box_outline_blank; iconColor = Colors.grey[400]!; shadow = Colors.grey[300]!; break;
      default: bg = Colors.transparent;
    }

    if (empty) {
      return Container(
        width: 24, height: 24, margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)),
      );
    }

    if (isGhost) {
      return Container(
        width: 24, height: 24, margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: bg.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
      );
    }

    // 3D BUTTON PHYSICS TILE
    return Container(
      width: 24, height: 24, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(4),
        border: Border(bottom: BorderSide(color: shadow, width: 3)), // The 3D Pop
      ),
      child: Center(child: Icon(icon, color: iconColor.withOpacity(0.5), size: 14)), // Accessibility Overlay
    );
  }

  // --- ZONE 1: OPPONENTS (30%) ---
  Widget _buildOpponentZone(String myName) {
    List<String> opponents = boards.keys.where((k) => k != myName).toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("OPPONENTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: opponents.length,
              itemBuilder: (context, i) {
                var oppBoard = boards[opponents[i]];
                List wall = oppBoard['wall'] ?? [];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(radius: 16, backgroundColor: tTeal, child: Text(opponents[i][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(opponents[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      
                      // Micro Wall Heatmap (5x5 grid of 4px squares)
                      Column(
                        children: List.generate(5, (r) => Row(
                          children: List.generate(5, (c) {
                            String tile = wall.length > r ? wall[r][c] : "";
                            return Container(
                              margin: const EdgeInsets.all(1), width: 6, height: 6,
                              decoration: BoxDecoration(color: tile == "" ? Colors.grey[200] : tTeal, borderRadius: BorderRadius.circular(1)),
                            );
                          }),
                        )),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- ZONE 2: MARKET (30%) ---
  Widget _buildMarketZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.center, spacing: 16, runSpacing: 16,
              children: factories.map((f) {
                return Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Center(
                    child: Wrap(
                      spacing: 2, runSpacing: 2, alignment: WrapAlignment.center,
                      children: f.map((t) => _buildPhysicsTile(t)).toList(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Center Pool
          Container(
            height: 40, width: double.infinity,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: center.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey))
                                    : Wrap(children: center.map((t) => _buildPhysicsTile(t)).toList()),
            ),
          )
        ],
      ),
    );
  }

  // --- ZONE 3: PLAYER WORKSHOP (40%) ---
  Widget _buildPlayerZone(String myName) {
    Map<String, dynamic> board = boards[myName] ?? {};
    List patternLines = board['pattern_lines'] ?? List.generate(5, (i) => List.filled(i + 1, ""));
    List wall = board['wall'] ?? List.generate(5, (_) => List.filled(5, ""));
    List floor = board['floor_line'] ?? [];
    List<String> shatterPenalties = ['-1', '-1', '-2', '-2', '-2', '-3', '-3'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey[400])),
              Text("SCORE: ${board['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tTeal)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LEFT: PATTERN STAIRCASE
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (r) {
                    List<String> rowTiles = List<String>.from(patternLines[r]);
                    return Row(
                      children: List.generate(r + 1, (c) {
                        return _buildPhysicsTile(rowTiles[c], empty: rowTiles[c] == "");
                      }),
                    );
                  }),
                ),
                const SizedBox(width: 24),
                // RIGHT: THE WALL
                Column(
                  children: List.generate(5, (r) {
                    List<String> rowTiles = List<String>.from(wall[r]);
                    return Row(
                      children: List.generate(5, (c) {
                        String tile = rowTiles[c];
                        if (tile != "") return _buildPhysicsTile(tile); // Filled
                        return _buildPhysicsTile(wallPattern[r][c], isGhost: true); // Ghost Pattern
                      }),
                    );
                  }),
                )
              ],
            ),
          ),
          // BOTTOM: SHATTER LINE (Floor)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) {
              String t = i < floor.length ? floor[i] : "";
              return Column(
                children: [
                  _buildPhysicsTile(t, empty: t == ""),
                  const SizedBox(height: 2),
                  Text(shatterPenalties[i], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: tTerra)),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          // ACTION BAR
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: tTeal, minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text("SET MOSAIC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "Player";

    return Scaffold(
      backgroundColor: tBg,
      // STRICT RULE 1: NO SCROLLING. Using SafeArea + Column + Expanded.
      body: SafeArea(
        child: Column(
          children: [
            // STRICT RULE 2: 30/30/40 Split
            Expanded(flex: 3, child: _buildOpponentZone(myName)),
            Expanded(flex: 3, child: _buildMarketZone()),
            Expanded(flex: 4, child: _buildPlayerZone(myName)),
          ],
        ),
      ),
    );
  }
}