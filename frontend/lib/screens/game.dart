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
            child: Transform.scale(
              scale: value < 0.5 ? 1.0 + value : 1.5 - value, 
              child: _buildTile(color, size: 24),
            )
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
                          Text(isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isMyTurn ? tTeal : Colors.grey, letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text("MOSAIC DRAFT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tInk.withOpacity(0.8))),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.emoji_events, color: tGold, size: 24), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen()))),
                    ],
                  ),
                ),

                Expanded(flex: 1, child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: opponents.isEmpty ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1))) : ListView(
                    shrinkWrap: true,
                    children: opponents.map((opp) {
                      var oppBoard = boards![opp] ?? {};
                      List oppWall = oppBoard['wall'] ?? [];
                      List oppFloor = oppBoard['floor_line'] ?? [];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 12, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tInk))),
                            // THE FIX: Unminified Opponent Heatmap logic (Proper bracket matching)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                5,
                                (r) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    5,
                                    (c) {
                                      String tile = (oppWall.length > r && oppWall[r].length > c) ? oppWall[r][c] : "";
                                      return Container(
                                        margin: const EdgeInsets.all(0.5), width: 4, height: 4, 
                                        decoration: BoxDecoration(color: tile == "" ? Colors.grey[200] : _getBaseColor(tile), borderRadius: BorderRadius.circular(1))
                                      );
                                    }
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(children: List.generate(oppFloor.length.clamp(0, 7), (i) => Container(margin: const EdgeInsets.only(right: 2), width: 3, height: 3, decoration: const BoxDecoration(color: tTerra, shape: BoxShape.circle)))),
                            const SizedBox(width: 8),
                            Text("${oppBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tInk)),
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
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
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
                                    width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: isKilnEmpty ? [] : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))]),
                                    child: Center(child: Wrap(spacing: 2, runSpacing: 2, alignment: WrapAlignment.center, children: factories![kIdx].map((c) {
                                      bool isHeld = heldColor == c && heldKilnIdx == kIdx;
                                      bool dim = heldColor != null && !isHeld && heldKilnIdx == kIdx;
                                      return GestureDetector(
                                        onTap: () {
                                          if (isHeld) { setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; }); } 
                                          else { setState(() { heldColor = c; heldKilnIdx = kIdx; heldCount = factories![kIdx].where((t) => t == c).length; HapticFeedback.lightImpact(); }); }
                                        },
                                        child: _buildTile(c, size: 20, opacity: dim ? 0.3 : 1.0, scale: isHeld ? 1.2 : 1.0),
                                      );
                                    }).toList())),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () => setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; }),
                            child: Container(
                              key: centerKey,
                              constraints: const BoxConstraints(minHeight: 64), width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.1)), boxShadow: const [BoxShadow(color: Colors.white, offset: Offset(0, 1), blurRadius: 0)]),
                              child: Center(child: center!.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)) : Wrap(spacing: 4, runSpacing: 4, children: center!.map((c) {
                                bool isHeld = heldColor == c && heldKilnIdx == -1;
                                return GestureDetector(
                                  onTap: c == "first_player" ? null : () {
                                    if (isHeld) { setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; }); }
                                    else { setState(() { heldColor = c; heldKilnIdx = -1; heldCount = center!.where((t) => t == c).length; HapticFeedback.lightImpact(); }); }
                                  },
                                  child: _buildTile(c, size: 24, scale: isHeld ? 1.15 : 1.0)
                                );
                              }).toList())),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                )),

                // ZONE 3: WORKSHOP
                Expanded(flex: 5, child: Container(
                  color: Colors.white, padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey[400])),
                        Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                      ]),
                      const SizedBox(height: 12),
                      
                      Expanded(child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(5, (rIdx) {
                                    bool isLegal = heldColor != null && _isRowLegal(rIdx, heldColor!);
                                    bool isHovered = hoveredRow == rIdx;
                                    return GestureDetector(
                                      onTap: isLegal ? () => _commitTurn(rIdx) : () { if (heldColor != null) HapticFeedback.vibrate(); },
                                      onPanUpdate: (_) => setState(() => hoveredRow = rIdx),
                                      child: Container(
                                        key: patternRowKeys[rIdx],
                                        margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: isHovered ? (isLegal ? tTeal : tTerra) : (isLegal ? tTeal.withOpacity(0.3) : Colors.transparent), width: 2)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(rIdx + 1, (cIdx) {
                                            String t = (patternLines.length > rIdx && patternLines[rIdx].length > cIdx) ? patternLines[rIdx][cIdx] : "";
                                            if (t != "") return _buildTile(t, size: 24);
                                            if (isHovered && isLegal && heldCount != null) {
                                               int emptySlots = (patternLines[rIdx] as List).where((s) => s == "").length;
                                               int rowLen = (patternLines[rIdx] as List).length;
                                               int slotIndex = (cIdx - (rowLen - emptySlots)).toInt();
                                               if (slotIndex >= 0 && slotIndex < heldCount!) return _buildTile(heldColor!, size: 24, isGhost: true);
                                            }
                                            return _buildTile("", size: 24, empty: true);
                                          }),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(width: 24),
                                Column(
                                  children: List.generate(5, (r) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(5, (c) {
                                      String t = (wall.length > r && wall[r].length > c) ? wall[r][c] : "";
                                      return t != "" ? _buildTile(t, size: 24) : _buildTile(wallPattern[r][c], size: 24, isGhost: true);
                                    })
                                  )),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: heldColor != null ? () => _commitTurn(-1) : null,
                              onPanUpdate: (_) => setState(() => hoveredRow = -1),
                              child: Container(
                                key: floorKey,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: hoveredRow == -1 ? tTeal : Colors.transparent, width: 2)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(7, (i) {
                                    String t = i < floor.length ? floor[i] : "";
                                    if (hoveredRow == -1 && heldColor != null && heldCount != null) {
                                      int emptyIdx = i - floor.length;
                                      if (emptyIdx >= 0 && emptyIdx < heldCount!) t = heldColor!;
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildTile(t, size: 24, empty: t == "", isGhost: hoveredRow == -1 && t == heldColor),
                                          const SizedBox(height: 4),
                                          Text(shatterPenalties[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: tTerra)),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),
                      PhysicsButton(
                        text: isMyTurn ? (heldColor != null ? "TAP ROW TO PLACE" : "SELECT TILES") : "WAITING FOR ${turnPlayer?.toUpperCase()}",
                        color: isMyTurn ? (heldColor != null ? tTeal : Colors.grey[400]!) : Colors.grey[300]!,
                        shadowColor: isMyTurn ? (heldColor != null ? const Color(0xFF1A695F) : Colors.grey[500]!) : Colors.grey[400]!,
                        onTap: () {
                          if (heldColor != null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tap a valid row on your board to place the tiles!"), duration: Duration(seconds: 1))); }
                        },
                      )
                    ],
                  ),
                )
              ),
            ],
          ),
          if (heldColor != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => setState(() { heldColor = null; selectedRow = null; heldKilnIdx = null; }), child: Container())),
        ],
      ),
    );
  }
}