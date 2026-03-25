import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../main.dart';
import 'victory.dart';

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
  late String turnPlayer;
  late StreamSubscription _sub;

  // INTERACTION STATE
  String? heldColor;
  int? heldCount;
  int? sourceKilnIdx; // -1 for Center Pool
  int? hoveredRow;

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
    turnPlayer = payload['turn_player'] ?? boards.keys.first;
    
    // Reset interaction on new turn
    heldColor = null; heldCount = null; sourceKilnIdx = null; hoveredRow = null;
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  // --- LOGIC: IS MOVE LEGAL? ---
  bool _isRowLegal(int rowIdx, String color) {
    String myName = socketService.playerName ?? "";
    Map<String, dynamic> myBoard = boards[myName] ?? {};
    List wall = myBoard['wall'] ?? [];
    List patternLines = myBoard['pattern_lines'] ?? [];

    // 1. Is the color already on the wall for this row?
    for (int col = 0; col < 5; col++) {
      if (wall[rowIdx][col] == color) return false;
    }
    // 2. Is the row already occupied by a different color?
    List rowTiles = patternLines[rowIdx];
    for (var t in rowTiles) {
      if (t != "" && t != color) return false;
    }
    return true;
  }

  // --- ACTIONS ---
  void _selectFromKiln(int kilnIdx, String color) {
    HapticFeedback.lightImpact();
    setState(() {
      heldColor = color;
      sourceKilnIdx = kilnIdx;
      heldCount = factories[kilnIdx].where((t) => t == color).length;
    });
  }

  void _selectFromCenter(String color) {
    HapticFeedback.lightImpact();
    setState(() {
      heldColor = color;
      sourceKilnIdx = -1;
      heldCount = center.where((t) => t == color).length;
    });
  }

  // --- UI COMPONENTS ---
  Widget _buildTile(String colorName, {double opacity = 1.0, bool isGhost = false, double scale = 1.0}) {
    Color bg; IconData? icon;
    switch (colorName) {
      case 'blue': bg = tTeal; icon = Icons.star; break;
      case 'red': bg = tTerra; icon = Icons.menu; break;
      case 'yellow': bg = tGold; icon = Icons.circle; break;
      case 'black': bg = tInk; icon = Icons.close; break;
      case 'white': bg = tIce; icon = Icons.square_outlined; break;
      default: bg = Colors.transparent;
    }
    
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: isGhost ? 0.3 : opacity,
        child: Container(
          width: 22, height: 22, margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(4),
            border: colorName == 'white' ? Border.all(color: Colors.grey[300]!) : null,
            boxShadow: opacity == 1.0 ? [const BoxShadow(color: Colors.black12, offset: Offset(0, 2))] : [],
          ),
          child: Center(child: Icon(icon, size: 10, color: (colorName == 'white' ? Colors.grey : Colors.white).withOpacity(0.5))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "Player";
    bool isMyTurn = turnPlayer == myName;
    Map<String, dynamic> myBoard = boards[myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? List.generate(5, (i) => List.filled(i + 1, ""));
    List wall = myBoard['wall'] ?? List.generate(5, (_) => List.filled(5, ""));

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isMyTurn ? "YOUR TURN" : "WAITING FOR $turnPlayer...", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isMyTurn ? tTeal : Colors.grey, letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text("MOSAIC ROUND 1", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tInk.withOpacity(0.8))),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.emoji_events_outlined, color: tGold), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen()))),
                    ],
                  ),
                ),

                // ZONE 2: MARKET (Dimmed if not turn)
                Expanded(
                  flex: 3,
                  child: Opacity(
                    opacity: isMyTurn ? 1.0 : 0.5,
                    child: IgnorePointer(
                      ignoring: !isMyTurn,
                      child: Column(
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                            children: List.generate(factories.length, (kIdx) => Container(
                              width: 64, height: 64, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Center(child: Wrap(children: factories[kIdx].map((c) {
                                bool isHeld = heldColor == c && sourceKilnIdx == kIdx;
                                bool dim = heldColor != null && !isHeld && sourceKilnIdx == kIdx;
                                return GestureDetector(
                                  onTap: () => _selectFromKiln(kIdx, c),
                                  child: _buildTile(c, opacity: dim ? 0.4 : 1.0, scale: isHeld ? 1.2 : 1.0),
                                );
                              }).toList())),
                            )),
                          ),
                          const SizedBox(height: 12),
                          // Center Pool
                          GestureDetector(
                            onTap: () => heldColor != null ? setState(() => heldColor = null) : null, // Tap background to undo
                            child: Container(
                              height: 44, width: 220, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(22)),
                              child: Center(child: center.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, color: Colors.grey)) : Wrap(children: center.map((c) => GestureDetector(onTap: () => _selectFromCenter(c), child: _buildTile(c))).toList())),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),

                // ZONE 3: WORKSHOP
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Colors.white, padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400])),
                          Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                        ]),
                        const SizedBox(height: 16),
                        Expanded(child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // PATTERN LINES (The Target)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(5, (rIdx) {
                                bool isLegal = heldColor != null && _isRowLegal(rIdx, heldColor!);
                                bool isHovered = hoveredRow == rIdx;
                                return GestureDetector(
                                  onTap: isLegal ? () {
                                    HapticFeedback.mediumImpact();
                                    // TODO: Send PLACEMENT to server
                                    setState(() { heldColor = null; hoveredRow = null; });
                                  } : () {
                                    if (heldColor != null) HapticFeedback.vibrate(); // Error
                                  },
                                  onPanUpdate: (_) => setState(() => hoveredRow = rIdx),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isHovered ? (isLegal ? tTeal : tTerra) : (isLegal ? tTeal.withOpacity(0.3) : Colors.transparent), width: 2),
                                    ),
                                    child: Row(
                                      children: List.generate(rIdx + 1, (cIdx) {
                                        String existing = patternLines[rIdx][cIdx];
                                        if (existing != "") return _buildTile(existing);
                                        // GHOSTING LOGIC
                                        if (isHovered && isLegal && heldCount != null) {
                                           // Show ghost if count reaches this slot
                                           return _buildTile(heldColor!, isGhost: true);
                                        }
                                        return Container(width: 22, height: 22, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)));
                                      }),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: 24),
                            // THE WALL
                            Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) => _buildTile(wall[r][c], opacity: wall[r][c] == "" ? 0.05 : 1.0))))),
                          ],
                        )),
                        const SizedBox(height: 16),
                        PhysicsButton(
                          text: heldColor != null ? "PLACE ${heldColor!.toUpperCase()}" : "SELECT TILES",
                          color: heldColor != null ? tTeal : Colors.grey[400]!,
                          shadowColor: heldColor != null ? const Color(0xFF1A695F) : Colors.grey[500]!,
                          onTap: () {},
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // UNDO OVERLAY (Tap table to deselect)
            if (heldColor != null) Positioned.fill(child: GestureDetector(onTap: () => setState(() => heldColor = null), child: Container(color: Colors.transparent))),
          ],
        ),
      ),
    );
  }
}