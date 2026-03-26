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

  // THE INTERACTION STATE
  String? heldColor;
  int? heldKilnIdx;
  int? heldCount;
  int? selectedRow; // Row chosen to place tiles

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
    
    // Reset selection on update
    heldColor = null; heldKilnIdx = null; heldCount = null; selectedRow = null;
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  // --- LOGIC ---
  bool _isRowLegal(int rowIdx, String color) {
    String myName = socketService.playerName ?? "";
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List wall = myBoard['wall'] ?? [];
    List patternLines = myBoard['pattern_lines'] ?? [];

    for (int col = 0; col < 5; col++) { if (wall[rowIdx][col] == color) return false; }
    for (var t in patternLines[rowIdx]) { if (t != "" && t != color) return false; }
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
      // Optimistically clear selection to prevent double tap
      setState(() { heldColor = null; selectedRow = null; }); 
    }
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
      case 'first_player': return Container(width: 22, height: 22, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: tGold, width: 2)), child: const Center(child: Text("1", style: TextStyle(color: tGold, fontWeight: FontWeight.bold, fontSize: 12))));
      default: bg = Colors.transparent;
    }
    
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: isGhost ? 0.4 : opacity,
        child: Container(
          width: 22, height: 22, margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: colorName == 'white' ? Border.all(color: Colors.grey[300]!) : null, boxShadow: opacity == 1.0 && !isGhost ? [const BoxShadow(color: Colors.black12, offset: Offset(0, 2))] : []),
          child: Center(child: Icon(icon, size: 10, color: (colorName == 'white' ? Colors.grey : Colors.white).withOpacity(0.5))),
        ),
      ),
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
          // Restored the Opponent Silhouette (Mini Heatmap)
          Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) {
            String tile = (wall.length > r && wall[r].length > c) ? wall[r][c] : "";
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
    if (factories == null || boards == null) { return const Scaffold(body: Center(child: CircularProgressIndicator(color: tTeal))); }

    String myName = socketService.playerName ?? "Player";
    bool isMyTurn = turnPlayer == myName;
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    List<String> opponents = boards!.keys.where((k) => k != myName).toList();

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
                          Text(isMyTurn ? "YOUR TURN" : "WAITING FOR ${turnPlayer?.toUpperCase()}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isMyTurn ? tTeal : Colors.grey, letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text("MOSAIC DRAFT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tInk.withOpacity(0.8))),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.emoji_events_outlined, color: tGold), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen()))),
                    ],
                  ),
                ),

                // ZONE 1: OPPONENTS
                Expanded(flex: 3, child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: opponents.isEmpty ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, color: Colors.grey))) : ListView(children: opponents.map((opp) => _buildOpponentRow(opp, boards![opp])).toList()),
                )),

                // ZONE 2: MARKET
                Expanded(flex: 3, child: Opacity(
                  opacity: isMyTurn ? 1.0 : 0.5,
                  child: IgnorePointer(
                    ignoring: !isMyTurn,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                          children: List.generate(factories!.length, (kIdx) => Container(
                            width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                            child: Center(child: Wrap(children: factories![kIdx].map((c) {
                              bool isHeld = heldColor == c && heldKilnIdx == kIdx;
                              bool dim = heldColor != null && !isHeld && heldKilnIdx == kIdx;
                              return GestureDetector(
                                onTap: () => setState(() { heldColor = c; heldKilnIdx = kIdx; heldCount = factories![kIdx].where((t) => t == c).length; }),
                                child: _buildTile(c, opacity: dim ? 0.3 : 1.0, scale: isHeld ? 1.2 : 1.0),
                              );
                            }).toList())),
                          )),
                        ),
                        const SizedBox(height: 16),
                        // CENTER POOL RESTORED
                        Container(
                          height: 44, width: 220, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(22)),
                          child: Center(child: center!.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, color: Colors.grey)) : Wrap(children: center!.map((c) => GestureDetector(
                            onTap: () => setState(() { heldColor = c; heldKilnIdx = -1; heldCount = center!.where((t) => t == c).length; }),
                            child: _buildTile(c, scale: (heldColor == c && heldKilnIdx == -1) ? 1.2 : 1.0)
                          )).toList())),
                        )
                      ],
                    ),
                  ),
                )),

                // ZONE 3: WORKSHOP
                Expanded(flex: 4, child: Container(
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
                          // PATTERN LINES (Interactive Target)
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(5, (r) {
                            bool isLegal = heldColor != null && _isRowLegal(r, heldColor!);
                            bool isSelected = selectedRow == r;
                            return GestureDetector(
                              onTap: isLegal ? () => setState(() => selectedRow = r) : null,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? tTeal : (isLegal ? tTeal.withOpacity(0.3) : Colors.transparent), width: 2)),
                                child: Row(children: List.generate(r + 1, (c) {
                                  String t = (patternLines.length > r && patternLines[r].length > c) ? patternLines[r][c] : "";
                                  if (t != "") return _buildTile(t);
                                  // GHOSTING PREVIEW
                                  if (isSelected && isLegal && heldCount != null) {
                                    int emptySlots = patternLines[r].where((s) => s == "").length;
                                    int slotIndex = c - (patternLines[r].length - emptySlots);
                                    if (slotIndex >= 0 && slotIndex < heldCount!) return _buildTile(heldColor!, isGhost: true);
                                  }
                                  return _buildTile("", empty: true);
                                })),
                              ),
                            );
                          })),
                          const SizedBox(width: 24),
                          // WALL
                          Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) {
                            String t = (wall.length > r && wall[r].length > c) ? wall[r][c] : "";
                            return t != "" ? _buildTile(t) : _buildTile(wallPattern[r][c], isGhost: true);
                          } )))),
                        ],
                      )),
                      const SizedBox(height: 12),
                      PhysicsButton(
                        text: heldColor != null && selectedRow != null ? "COMMIT TURN" : "SELECT TILES",
                        color: heldColor != null && selectedRow != null ? tTeal : Colors.grey[400]!,
                        shadowColor: heldColor != null && selectedRow != null ? const Color(0xFF1A695F) : Colors.grey[500]!,
                        onTap: _commitTurn,
                      ),
                    ],
                  ),
                )),
              ],
            ),
            
            // BACKGROUND UNDO LISTENER (Tap outside to deselect)
            if (heldColor != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => setState(() { heldColor = null; selectedRow = null; }), child: Container())),
          ],
        ),
      ),
    );
  }
}