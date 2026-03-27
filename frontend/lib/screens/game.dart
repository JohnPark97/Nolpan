import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../main.dart';
import 'victory.dart';

const List<List<String>> wallPattern = [
  ['blue', 'yellow', 'red', 'black', 'purple'],
  ['purple', 'blue', 'yellow', 'red', 'black'],
  ['black', 'purple', 'blue', 'yellow', 'red'],
  ['red', 'black', 'purple', 'blue', 'yellow'],
  ['yellow', 'red', 'black', 'purple', 'blue'],
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

  bool _isAnimatingScoring = false;
  bool _isWaitingForServer = false;
  bool _showSlide = false;
  bool _showPop = false;
  bool _showShatter = false;

  List<int> _scoringRows = [];
  Map<String, dynamic>? _incomingPayload;

  @override
  void initState() {
    super.initState();
    _updateState(widget.initialState);
    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'GAME_UPDATE') {
        _handleIncomingState(msg['payload'], isGameOver: false);
      } else if (msg['type'] == 'GAME_OVER') {
        _handleIncomingState(msg['payload'], isGameOver: true);
      }
    });
  }

  void _handleIncomingState(Map<String, dynamic> payload, {bool isGameOver = false}) async {
    if (boards == null || payload['factories'] == null) {
      _updateState(payload);
      if (isGameOver && mounted) { _sub.cancel(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VictoryScreen(finalState: payload))); }
      return;
    }

    bool oldEmpty = factories!.every((f) => f.isEmpty);
    bool newFull = (payload['factories'] as List).isNotEmpty && (payload['factories'][0] as List).isNotEmpty;

    if (oldEmpty && (newFull || isGameOver)) {
      _incomingPayload = payload;
      String myName = socketService.playerName ?? "";
      List patternLines = boards![myName]?['pattern_lines'] ?? [];
      
      // FIX 1: ONLY score rows that are 100% FULL
      List<int> validScoringRows = [];
      for (int r = 0; r < 5; r++) {
        int emptySlots = (patternLines[r] as List).where((s) => s == "").length;
        if (emptySlots == 0 && (patternLines[r] as List).isNotEmpty && patternLines[r][0] != "") {
          validScoringRows.add(r);
        }
      }

      setState(() { _isAnimatingScoring = true; _scoringRows = validScoringRows; _showSlide = true; });
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() { _showPop = true; });
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() { _showShatter = true; });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      setState(() {
        _isAnimatingScoring = false;
        _showSlide = false;
        _showPop = false;
        _showShatter = false;
        _scoringRows.clear();
        _incomingPayload = null;
        _updateState(payload);
      });

      if (isGameOver && mounted) {
        _sub.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VictoryScreen(finalState: payload)));
      }
    } else {
      _updateState(payload);
    }
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
    setState(() {
      heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null;
      _isWaitingForServer = false; 
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  String? _getPlacementError(int rowIdx, String color) {
    if (rowIdx == -1) return null; 

    String myName = socketService.playerName ?? "";
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List wall = myBoard['wall'] ?? [];
    List patternLines = myBoard['pattern_lines'] ?? [];

    for (int col = 0; col < 5; col++) {
      if (wall.length > rowIdx && wall[rowIdx].length > col && wall[rowIdx][col] == color) {
        return "You've already built a ${_capitalize(color)} tile in that row!";
      }
    }
    if (patternLines.length > rowIdx) {
      for (var t in patternLines[rowIdx]) {
        if (t != "" && t != color) return "Hold up, boss! That row is already holding another color.";
      }
      int emptySlots = (patternLines[rowIdx] as List).where((s) => s == "").length;
      if (emptySlots == 0) return "That row is completely full!";
    }
    return null; 
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
    
    setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; _isWaitingForServer = true; });
    
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
      case 'purple': return const Color(0xFF8E44AD); 
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
      case 'purple': icon = Icons.diamond; break; 
      case 'first_player': 
        return Container( // FIX 4: First Player Physical Tile Design
          width: size, height: size, margin: const EdgeInsets.all(1.5), 
          decoration: BoxDecoration(color: const Color(0xFFF3E5AB), borderRadius: BorderRadius.circular(4), border: Border.all(color: tGold, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), offset: const Offset(0, 3))]), 
          child: Center(child: Text("1", style: TextStyle(color: tGold, fontWeight: FontWeight.bold, fontSize: size * 0.5)))
        );
    }
    
    Widget tile = Transform.scale(
      scale: scale,
      child: Container(
        width: size, height: size, margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isGhost ? bg.withOpacity(0.15) : bg.withOpacity(opacity),
          borderRadius: BorderRadius.circular(4),
          boxShadow: (opacity == 1.0 && !isGhost) ? [BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 3))] : [],
        ),
        child: Center(child: Icon(icon, size: size * 0.45, color: Colors.white.withOpacity(0.5 * opacity))),
      ),
    );
    
    return tile;
  }

  @override
  Widget build(BuildContext context) {
    if (factories == null || boards == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: tTeal)));
    String myName = socketService.playerName ?? "Player";
    bool isMyTurn = turnPlayer == myName && !_isAnimatingScoring && !_isWaitingForServer;
    
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
            if (heldColor != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; }))),
            
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 2)),
                      IconButton(icon: const Icon(Icons.emoji_events, color: tGold, size: 24), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VictoryScreen(finalState: {'boards': boards})))),
                    ],
                  ),
                ),

                // FIX 2: MAXIMIZED OPPONENT BOARD
                Expanded(flex: 2, child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: opponents.isEmpty ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, color: Colors.grey))) : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: opponents.map((opp) {
                      var board = boards![opp] ?? {};
                      List oppWall = board['wall'] ?? [];
                      List oppFloor = board['floor_line'] ?? [];
                      List oppPattern = board['pattern_lines'] ?? [];
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [CircleAvatar(radius: 10, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))), const SizedBox(width: 4), Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)]),
                                  Text("${board['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                ]
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: List.generate(5, (r) => Row(
                                              children: List.generate(r + 1, (c) {
                                                String tile = (oppPattern.length > r && oppPattern[r].length > c) ? oppPattern[r][c] : "";
                                                return Container(margin: const EdgeInsets.all(0.5), width: 3, height: 3, decoration: BoxDecoration(color: tile == "" ? Colors.grey[200] : _getBaseColor(tile), borderRadius: BorderRadius.circular(0.5)));
                                              })
                                            ))
                                          ),
                                          const SizedBox(width: 4),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(5, (r) => Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(5, (c) {
                                                String tile = (oppWall.length > r && oppWall[r].length > c) ? oppWall[r][c] : "";
                                                Color bg = tile != "" ? _getBaseColor(tile) : _getBaseColor(wallPattern[r][c]).withOpacity(0.1);
                                                return Container(margin: const EdgeInsets.all(0.5), width: 3, height: 3, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(0.5)));
                                              })
                                            )),
                                          ),
                                        ]
                                      ),
                                      const SizedBox(height: 4),
                                      Row(mainAxisSize: MainAxisSize.min, children: List.generate(7, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 0.5), width: 2, height: 2, decoration: BoxDecoration(color: i < oppFloor.length ? tTerra : Colors.grey[200], shape: BoxShape.circle)))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )),

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
                        Container(
                          key: centerKey,
                          constraints: const BoxConstraints(minHeight: 80), width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(color: const Color(0xFFE5E0D8), borderRadius: BorderRadius.circular(12), border: const Border(top: BorderSide(color: Colors.black12, width: 2))), // Recessed Look
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

                Expanded(flex: 4, child: Container(
                  color: Colors.white, padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                      ]),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          children: [
                            ...List.generate(5, (rIdx) {
                              String? errorMsg = heldColor != null ? _getPlacementError(rIdx, heldColor!) : null;
                              bool isLegal = heldColor != null && errorMsg == null;
                              bool isHovered = hoveredRow == rIdx;
                              
                              return GestureDetector(
                                onTap: heldColor != null ? () {
                                  if (isLegal) _commitTurn(rIdx);
                                  else {
                                    HapticFeedback.vibrate();
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: tTerra, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
                                  }
                                } : null,
                                onPanUpdate: (_) => setState(() => hoveredRow = rIdx),
                                child: Container(
                                  key: patternRowKeys[rIdx],
                                  margin: const EdgeInsets.symmetric(vertical: 2),
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

                                          Widget tileW;
                                          if (slotIdx < ghostStart) tileW = _buildTile("", size: 24, empty: true);
                                          else if (slotIdx >= ghostStart && slotIdx < emptyCount) tileW = _buildTile(heldColor!, size: 24, isGhost: true);
                                          else tileW = _buildTile(rowColor, size: 24);

                                          // THE JUICE: SLIDE AND SHATTER
                                          if (_scoringRows.contains(rIdx)) {
                                            if (_showSlide && slotIdx == rIdx) { 
                                              int targetC = wallPattern[rIdx].indexOf(rowColor);
                                              double distance = 24.0 + (targetC * 27.0);
                                              tileW = AnimatedContainer(duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic, transform: Matrix4.translationValues(distance, 0, 0), child: tileW);
                                            } else if (_showShatter && slotIdx < rIdx) { 
                                              tileW = AnimatedContainer(duration: const Duration(milliseconds: 500), curve: Curves.easeInCubic, transform: Matrix4.translationValues(0, 300.0, 0), child: tileW);
                                            }
                                          }
                                          return tileW;
                                        }),
                                      ),
                                      const SizedBox(width: 24),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(5, (cIdx) {
                                          String t = (wall.length > rIdx && wall[rIdx].length > cIdx) ? wall[rIdx][cIdx] : "";
                                          Widget slotW = t != "" ? _buildTile(t, size: 24) : _buildTile(wallPattern[rIdx][cIdx], size: 24, isGhost: true);
                                          
                                          // FIX 3: FLOATING COMBAT TEXT
                                          if (_showPop && _scoringRows.contains(rIdx)) {
                                            String rColor = patternLines[rIdx][0];
                                            if (wallPattern[rIdx][cIdx] == rColor) {
                                              int pts = _incomingPayload?['last_scored']?[myName]?[rIdx.toString()] ?? 1;
                                              slotW = Stack(
                                                alignment: Alignment.center,
                                                clipBehavior: Clip.none,
                                                children: [
                                                  slotW,
                                                  Positioned(
                                                    child: TweenAnimationBuilder<double>(
                                                      tween: Tween(begin: 0.0, end: 1.0),
                                                      duration: const Duration(milliseconds: 800),
                                                      curve: Curves.easeOutCubic,
                                                      builder: (context, val, child) {
                                                        return Transform.translate(
                                                          offset: Offset(0, -30 * val),
                                                          child: Opacity(
                                                            opacity: 1.0 - val,
                                                            child: Text("+$pts", style: const TextStyle(color: tGold, fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
                                                          )
                                                        );
                                                      }
                                                    )
                                                  )
                                                ]
                                              );
                                            }
                                          }
                                          return slotW;
                                        }),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
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
                                    
                                    Widget tileW = _buildTile(t, size: 24, empty: t == "", isGhost: hoveredRow == -1 && t == heldColor);
                                    if (_showShatter && t != "") {
                                      tileW = AnimatedContainer(duration: const Duration(milliseconds: 500), curve: Curves.easeInCubic, transform: Matrix4.translationValues(0, 300.0, 0), child: tileW);
                                    }

                                    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [tileW, const SizedBox(height: 4), Text(shatterPenalties[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tTerra))]));
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