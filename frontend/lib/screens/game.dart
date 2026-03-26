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
  int? hoveredRow;

  final List<GlobalKey> factoryKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey centerKey = GlobalKey();
  final List<GlobalKey> patternRowKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey floorKey = GlobalKey();

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
    if (center != null) {
      center!.sort((a, b) {
        if (a == "first_player") return -1;
        if (b == "first_player") return 1;
        return a.compareTo(b);
      });
    }
    boards = Map<String, dynamic>.from(payload['boards'] ?? {});
    turnPlayer = payload['turn_player'] ?? (boards!.isNotEmpty ? boards!.keys.first : "...");
    heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null;
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

  void _flyTile(GlobalKey startKey, GlobalKey endKey, String color, VoidCallback onComplete) {
    final RenderBox? startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = endKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) { onComplete(); return; }
    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, double value, child) {
          return Positioned(
            left: startPos.dx + (endPos.dx - startPos.dx) * value,
            top: startPos.dy + (endPos.dy - startPos.dy) * value,
            child: Transform.scale(scale: value < 0.5 ? 1.0 + value : 1.5 - value, child: _buildTile(color, size: 24))
          );
        },
        onEnd: () { entry.remove(); onComplete(); }
      )
    );
    Overlay.of(context).insert(entry);
  }

  void _commitTurn(int targetRow) {
    if (heldColor == null || heldKilnIdx == null) return;
    HapticFeedback.mediumImpact();
    GlobalKey startKey = heldKilnIdx == -1 ? centerKey : factoryKeys[heldKilnIdx!];
    GlobalKey endKey = targetRow == -1 ? floorKey : patternRowKeys[targetRow];
    String colorToFly = heldColor!;
    int kilnIdxToSend = heldKilnIdx!;
    setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; });
    _flyTile(startKey, endKey, colorToFly, () {
      if (socketService.currentRoomCode != null) {
        socketService.send('PICK_TILES', {
          'code': socketService.currentRoomCode,
          'player': socketService.playerName,
          'kiln_idx': kilnIdxToSend,
          'color': colorToFly,
          'target_row': targetRow
        });
      }
    });
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
    if (empty) return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)));
    Color bg = _getBaseColor(colorName);
    IconData? icon;
    switch (colorName) {
      case 'blue': icon = Icons.star; break;
      case 'red': icon = Icons.menu; break;
      case 'yellow': icon = Icons.circle; break;
      case 'black': icon = Icons.close; break;
      case 'white': icon = Icons.square_outlined; break;
      case 'first_player': 
        return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: tGold, width: 2)), child: const Center(child: Text("1", style: TextStyle(color: tGold, fontWeight: FontWeight.bold, fontSize: 10))));
    }
    return Transform.scale(
      scale: scale,
      child: Container(
        width: size, height: size, margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isGhost ? bg.withOpacity(0.15) : bg.withOpacity(opacity),
          borderRadius: BorderRadius.circular(4),
          border: colorName == 'white' ? Border.all(color: Colors.grey[300]!) : null,
        ),
        child: Center(child: Icon(icon, size: size * 0.45, color: (colorName == 'white' ? Colors.grey : Colors.white).withOpacity(0.5 * opacity))),
      ),
    );
  }

  // --- COMPONENT: OPPONENT MINI BOARD ---
  Widget _buildMiniWorkshop(Map<String, dynamic> board) {
    List wall = board['wall'] ?? [];
    List pattern = board['pattern_lines'] ?? [];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini Staircase
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (r) => Row(
            children: List.generate(r + 1, (c) {
              String tile = (pattern.length > r && pattern[r].length > c) ? pattern[r][c] : "";
              return Container(margin: const EdgeInsets.all(0.5), width: 5, height: 5, decoration: BoxDecoration(color: tile == "" ? Colors.grey[200] : _getBaseColor(tile), borderRadius: BorderRadius.circular(1)));
            })
          ))
        ),
        const SizedBox(width: 8),
        // Mini Wall
        Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (r) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (c) {
              String tile = (wall.length > r && wall[r].length > c) ? wall[r][c] : "";
              Color bg = tile != "" ? _getBaseColor(tile) : _getBaseColor(wallPattern[r][c]).withOpacity(0.1);
              return Container(margin: const EdgeInsets.all(0.5), width: 5, height: 5, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(1)));
            })
          )),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (factories == null || boards == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: tTeal)));
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
            // THE FIX 1: UNDO LAYER AT BOTTOM OF STACK
            if (heldColor != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; }))),
            
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 2)),
                      IconButton(icon: const Icon(Icons.emoji_events, color: tGold, size: 24), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen()))),
                    ],
                  ),
                ),

                // ZONE 1: COMPRESSED OPPONENTS (FIX 2 & 5)
                Expanded(flex: 1, child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: opponents.isEmpty ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, color: Colors.grey))) : ListView(
                    shrinkWrap: true,
                    children: opponents.map((opp) {
                      var board = boards![opp] ?? {};
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 10, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            // FIX 2: Rendering Mini Ghost Workshop
                            _buildMiniWorkshop(board),
                            const SizedBox(width: 12),
                            Text("${board['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )),

                // ZONE 2: MARKET
                Expanded(flex: 3, child: Opacity(
                  opacity: isMyTurn ? 1.0 : 0.5,
                  child: IgnorePointer(
                    ignoring: !isMyTurn,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(factories!.length, (kIdx) {
                              bool isKilnEmpty = factories![kIdx].isEmpty;
                              return Opacity(
                                opacity: isKilnEmpty ? 0.2 : 1.0,
                                child: Container(
                                  key: factoryKeys[kIdx],
                                  width: 54, height: 54, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Center(child: Wrap(spacing: 2, runSpacing: 2, children: factories![kIdx].map((c) {
                                    bool isHeld = heldColor == c && heldKilnIdx == kIdx;
                                    bool dim = heldColor != null && !isHeld && heldKilnIdx == kIdx;
                                    return GestureDetector(
                                      onTap: () => setState(() { heldColor = c; heldKilnIdx = kIdx; heldCount = factories![kIdx].where((t) => t == c).length; }),
                                      child: _buildTile(c, size: 18, opacity: dim ? 0.3 : 1.0, scale: isHeld ? 1.2 : 1.0),
                                    );
                                  }).toList())),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // FIX 3: RECESSED TRAY
                        Container(
                          key: centerKey,
                          constraints: const BoxConstraints(minHeight: 80), width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(color: const Color(0xFFF0EDE9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
                          child: Center(child: center!.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, color: Colors.grey)) : Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(spacing: 4, runSpacing: 4, children: center!.map((c) => GestureDetector(
                              onTap: c == "first_player" ? null : () => setState(() { heldColor = c; heldKilnIdx = -1; heldCount = center!.where((t) => t == c).length; }),
                              child: _buildTile(c, size: 22, scale: (heldColor == c && heldKilnIdx == -1) ? 1.2 : 1.0)
                            )).toList()),
                          )),
                        )
                      ],
                    ),
                  ),
                )),

                // ZONE 3: WORKSHOP (FIX 4 & 5)
                Expanded(flex: 5, child: Container(
                  color: Colors.white, padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                      ]),
                      const Spacer(), // FIX 4: Vertical Centering
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          children: [
                            ...List.generate(5, (rIdx) {
                              bool isLegal = heldColor != null && _isRowLegal(rIdx, heldColor!);
                              bool isHovered = hoveredRow == rIdx;
                              return GestureDetector(
                                // FIX 1: Clicking row restores logic
                                onTap: isLegal ? () => _commitTurn(rIdx) : null,
                                onPanUpdate: (_) => setState(() => hoveredRow = rIdx),
                                child: Container(
                                  key: patternRowKeys[rIdx],
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  color: Colors.transparent,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(5, (cIdx) {
                                          if (cIdx < 4 - rIdx) return Container(width: 24, height: 24, margin: const EdgeInsets.all(1.5)); 
                                          int slotIdx = cIdx - (4 - rIdx);
                                          int capacity = rIdx + 1;
                                          int filled = (patternLines[rIdx] as List).where((s) => s != "").length;
                                          String rowColor = filled > 0 ? (patternLines[rIdx] as List).firstWhere((s) => s != "") : "";
                                          int emptyCount = capacity - filled;

                                          int ghostStart = emptyCount;
                                          if (isHovered && isLegal && heldCount != null) {
                                            ghostStart = emptyCount - heldCount!;
                                            if (ghostStart < 0) ghostStart = 0;
                                          }

                                          if (slotIdx < ghostStart) return _buildTile("", size: 24, empty: true);
                                          else if (slotIdx >= ghostStart && slotIdx < emptyCount) return _buildTile(heldColor!, size: 24, isGhost: true);
                                          else return _buildTile(rowColor, size: 24);
                                        }),
                                      ),
                                      const SizedBox(width: 24),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(5, (cIdx) {
                                          String t = (wall.length > rIdx && wall[rIdx].length > cIdx) ? wall[rIdx][cIdx] : "";
                                          return t != "" ? _buildTile(t, size: 24) : _buildTile(wallPattern[rIdx][cIdx], size: 24, isGhost: true);
                                        }),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 24), // FIX 4: Margin
                            GestureDetector(
                              onTap: heldColor != null ? () => _commitTurn(-1) : null,
                              onPanUpdate: (_) => setState(() => hoveredRow = -1),
                              child: Container(
                                key: floorKey, padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: hoveredRow == -1 ? tTeal : Colors.transparent, width: 2)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(7, (i) {
                                    String t = i < floor.length ? floor[i] : "";
                                    if (hoveredRow == -1 && heldColor != null && heldCount != null) { if (i - floor.length >= 0 && i - floor.length < heldCount!) t = heldColor!; }
                                    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [_buildTile(t, size: 24, empty: t == "", isGhost: hoveredRow == -1 && t == heldColor), const SizedBox(height: 4), Text(shatterPenalties[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tTerra))]));
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}