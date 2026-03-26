import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String? heldColor;
  int? heldKilnIdx;
  int? heldCount;
  int? selectedRow;

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
    if (payload['factories'] != null) { factories = (payload['factories'] as List).map((f) => List<String>.from(f)).toList(); }
    center = List<String>.from(payload['center'] ?? []);
    boards = Map<String, dynamic>.from(payload['boards'] ?? {});
    turnPlayer = payload['turn_player'] ?? (boards!.isNotEmpty ? boards!.keys.first : "...");
    heldColor = null; heldKilnIdx = null; heldCount = null; selectedRow = null;
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  bool _isRowLegal(int rowIdx, String color) {
    String myName = socketService.playerName ?? "";
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List wall = myBoard['wall'] ?? [];
    List patternLines = myBoard['pattern_lines'] ?? [];

    if (rowIdx == -1) return true; 

    for (int col = 0; col < 5; col++) {
      if (wall.length > rowIdx && wall[rowIdx].length > col && wall[rowIdx][col] == color) return false;
    }
    if (patternLines.length > rowIdx) {
      for (var t in patternLines[rowIdx]) { if (t != "" && t != color) return false; }
    }
    return true;
  }

  void _commitTurn() {
    if (heldColor != null && selectedRow != null && socketService.currentRoomCode != null) {
      socketService.send('PICK_TILES', {
        'code': socketService.currentRoomCode,
        'player': socketService.playerName,
        'kiln_idx': heldKilnIdx,
        'color': heldColor,
        'target_row': selectedRow
      });
      setState(() { heldColor = null; selectedRow = null; heldKilnIdx = null; }); 
    }
  }

  Color _getBaseColor(String colorName) {
    switch (colorName) {
      case 'blue': return tTeal;
      case 'red': return tTerra;
      case 'yellow': return tGold;
      case 'black': return tInk;
      case 'white': return tIce;
      default: return Colors.transparent;
    }
  }

  Widget _buildTile(String colorName, {double size = 20, double opacity = 1.0, bool isGhost = false, bool empty = false, double scale = 1.0}) {
    if (empty) {
      return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)));
    }

    Color bg = _getBaseColor(colorName);
    IconData? icon; Color shadow = Colors.transparent;
    
    switch (colorName) {
      case 'blue': icon = Icons.star; shadow = const Color(0xFF1A695F); break;
      case 'red': icon = Icons.menu; shadow = const Color(0xFFA84128); break;
      case 'yellow': icon = Icons.circle; shadow = const Color(0xFFC9A24A); break;
      case 'black': icon = Icons.close; shadow = const Color(0xFF11121A); break;
      case 'white': icon = Icons.square_outlined; shadow = Colors.grey[300]!; break;
      case 'first_player': 
        return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: tGold, width: 2)), child: const Center(child: Text("1", style: TextStyle(color: tGold, fontWeight: FontWeight.bold, fontSize: 10))));
    }

    return Transform.scale(
      scale: scale,
      child: Container(
        width: size, height: size, margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isGhost ? bg.withOpacity(0.2) : bg.withOpacity(opacity),
          borderRadius: BorderRadius.circular(4),
          border: colorName == 'white' ? Border.all(color: Colors.grey[300]!) : null,
          boxShadow: (opacity == 1.0 && !isGhost) ? [BoxShadow(color: shadow, offset: const Offset(0, 2))] : [],
        ),
        child: Center(child: Icon(icon, size: size * 0.45, color: (colorName == 'white' ? Colors.grey : Colors.white).withOpacity(0.5 * opacity))),
      ),
    );
  }

  Widget _buildOpponentZone(String myName, List<String> opponents) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: opponents.isEmpty 
        ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)))
        : ListView(
            children: opponents.map((opp) {
              var oppBoard = boards![opp] ?? {};
              List oppWall = oppBoard['wall'] ?? [];
              List oppFloor = oppBoard['floor_line'] ?? [];
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(opp, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tInk))),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (r) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (c) {
                          String tile = (oppWall.length > r && oppWall[r].length > c) ? oppWall[r][c] : "";
                          return Container(margin: const EdgeInsets.all(0.5), width: 5, height: 5, decoration: BoxDecoration(color: tile == "" ? Colors.grey[200] : _getBaseColor(tile), borderRadius: BorderRadius.circular(1)));
                        })
                      )),
                    ),
                    const SizedBox(width: 12),
                    Row(children: List.generate(oppFloor.length.clamp(0, 7), (i) => Container(margin: const EdgeInsets.only(right: 2), width: 4, height: 4, decoration: const BoxDecoration(color: tTerra, shape: BoxShape.circle)))),
                    const SizedBox(width: 12),
                    Text("${oppBoard['score'] ?? 0}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: tInk)),
                  ],
                ),
              );
            }).toList(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (factories == null || boards == null) { return const Scaffold(body: Center(child: CircularProgressIndicator(color: tTeal))); }

    String myName = socketService.playerName ?? "Player";
    bool isMyTurn = turnPlayer == myName;
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    List<String> opponents = boards!.keys.where((k) => k != myName).toList();
    
    const List<String> shatterPenalties = ['-1', '-1', '-2', '-2', '-2', '-3', '-3'];

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isMyTurn ? "YOUR TURN" : "WAITING FOR ${turnPlayer?.toUpperCase()}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isMyTurn ? tTeal : Colors.grey, letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text("MOSAIC DRAFT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tInk.withOpacity(0.8))),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.emoji_events, color: tGold, size: 24), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen()))),
                    ],
                  ),
                ),

                Expanded(flex: 3, child: _buildOpponentZone(myName, opponents)),

                Expanded(flex: 3, child: Opacity(
                  opacity: isMyTurn ? 1.0 : 0.5,
                  child: IgnorePointer(
                    ignoring: !isMyTurn,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            alignment: WrapAlignment.center, spacing: 16, runSpacing: 16,
                            children: List.generate(factories!.length, (kIdx) => Container(
                              width: 86, height: 86, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
                              child: Center(child: Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: factories![kIdx].map((c) {
                                bool isHeld = heldColor == c && heldKilnIdx == kIdx;
                                bool dim = heldColor != null && !isHeld && heldKilnIdx == kIdx;
                                return GestureDetector(
                                  onTap: () => setState(() { heldColor = c; heldKilnIdx = kIdx; heldCount = factories![kIdx].where((t) => t == c).length; }),
                                  child: _buildTile(c, size: 28, opacity: dim ? 0.3 : 1.0, scale: isHeld ? 1.15 : 1.0),
                                );
                              }).toList())),
                            )),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => heldColor != null ? setState(() => heldColor = null) : null,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56), // THE FIX: Proper constraints wrapper!
                            width: 260, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05))),
                            child: Center(child: center!.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)) : Wrap(spacing: 4, runSpacing: 4, children: center!.map((c) => GestureDetector(
                              onTap: () => setState(() { heldColor = c; heldKilnIdx = -1; heldCount = center!.where((t) => t == c).length; }),
                              child: _buildTile(c, size: 24, scale: (heldColor == c && heldKilnIdx == -1) ? 1.15 : 1.0)
                            )).toList())),
                          ),
                        )
                      ],
                    ),
                  ),
                )),

                Expanded(flex: 4, child: Container(
                  color: Colors.white, padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey[400])),
                        Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                      ]),
                      const SizedBox(height: 12),
                      
                      Expanded(child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(5, (rIdx) {
                              bool isLegal = heldColor != null && _isRowLegal(rIdx, heldColor!);
                              bool isSelected = selectedRow == rIdx;
                              return GestureDetector(
                                onTap: isLegal ? () => setState(() => selectedRow = rIdx) : () { if (heldColor != null) HapticFeedback.vibrate(); },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? tTeal : (isLegal ? tTeal.withOpacity(0.3) : Colors.transparent), width: 2)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(rIdx + 1, (cIdx) {
                                      String t = (patternLines.length > rIdx && patternLines[rIdx].length > cIdx) ? patternLines[rIdx][cIdx] : "";
                                      if (t != "") return _buildTile(t, size: 20);
                                      if (isSelected && isLegal && heldCount != null) {
                                         int emptySlots = (patternLines[rIdx] as List).where((s) => s == "").length;
                                         int rowLen = (patternLines[rIdx] as List).length;
                                         int slotIndex = (cIdx - (rowLen - emptySlots)).toInt(); // THE FIX: Explicit cast to integer
                                         if (slotIndex >= 0 && slotIndex < heldCount!) return _buildTile(heldColor!, size: 20, isGhost: true);
                                      }
                                      return _buildTile("", size: 20, empty: true); // THE FIX: Restored empty flag
                                    }),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (r) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (c) {
                                String t = (wall.length > r && wall[r].length > c) ? wall[r][c] : "";
                                return t != "" ? _buildTile(t, size: 20) : _buildTile(wallPattern[r][c], size: 20, isGhost: true);
                              })
                            )),
                          ),
                        ],
                      )),
                      const SizedBox(height: 8),
                      
                      GestureDetector(
                        onTap: (heldColor != null) ? () => setState(() => selectedRow = -1) : null,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: selectedRow == -1 ? tTeal : Colors.transparent, width: 2)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(7, (i) {
                              String t = i < floor.length ? floor[i] : "";
                              if (selectedRow == -1 && heldColor != null && heldCount != null) {
                                int emptyIdx = i - floor.length;
                                if (emptyIdx >= 0 && emptyIdx < heldCount!) t = heldColor!;
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTile(t, size: 24, empty: t == "", isGhost: selectedRow == -1 && t == heldColor),
                                    const SizedBox(height: 4),
                                    Text(shatterPenalties[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tTerra)),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      PhysicsButton(
                        text: heldColor != null && selectedRow != null ? "COMMIT TURN" : "SELECT TILES",
                        color: heldColor != null && selectedRow != null ? tTeal : Colors.grey[400]!,
                        shadowColor: heldColor != null && selectedRow != null ? const Color(0xFF1A695F) : Colors.grey[500]!,
                        onTap: _commitTurn,
                      )
                    ],
                  ),
                )),
              ],
            ),
            if (heldColor != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => setState(() { heldColor = null; selectedRow = null; heldKilnIdx = null; }), child: Container())),
          ],
        ),
      ),
    );
  }
}