import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../../main.dart';
import '../../../core/ui/physics_button.dart';

const List<List<String>> wallPattern = [
  ['blue', 'yellow', 'red', 'black', 'amethyst'],
  ['amethyst', 'blue', 'yellow', 'red', 'black'],
  ['black', 'amethyst', 'blue', 'yellow', 'red'],
  ['red', 'black', 'amethyst', 'blue', 'yellow'],
  ['yellow', 'red', 'black', 'amethyst', 'blue'],
];

class GameScreen extends StatefulWidget {
  final String roomCode;
  final Map<String, dynamic> initialState;

  const GameScreen({super.key, required this.roomCode, required this.initialState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Map<String, dynamic> _gameState;
  late StreamSubscription _sub;
  bool _isReviewingBoard = false;

  String? heldColor;
  int? heldKilnIdx;
  int? heldCount;
  int? hoveredRow;

  final List<GlobalKey> factoryKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey centerKey = GlobalKey();
  final List<GlobalKey> patternRowKeys = List.generate(5, (_) => GlobalKey());
  final List<List<GlobalKey>> wallKeys = List.generate(5, (_) => List.generate(5, (_) => GlobalKey()));
  final GlobalKey floorKey = GlobalKey();

  bool _showShatter = false;

  @override
  void initState() {
    super.initState();
    _gameState = widget.initialState;
    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'GAME_UPDATE' || msg['type'] == 'GAME_OVER' || msg['type'] == 'GAME_STARTED') {
        if (mounted) setState(() { 
          _gameState = msg['payload']; 
          _showShatter = false; 
          _isReviewingBoard = false; 
        });
      } else if (msg['type'] == 'RETURN_TO_LOBBY') {
        if (mounted) Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _commitTurn(int targetRow) async {
    if (heldColor == null || heldKilnIdx == null) return;
    HapticFeedback.mediumImpact();

    String cColor = heldColor!;
    int kIdx = heldKilnIdx!;
    int cCount = heldCount!;

    GlobalKey sourceKey = kIdx == -1 ? centerKey : factoryKeys[kIdx];
    GlobalKey destKey = targetRow == -1 ? floorKey : patternRowKeys[targetRow];
    
    // V39 FIX: Added try/catch safety net so UI animation glitches never kill network payload
    try {
      _playDraftingFlight(sourceKey, destKey, cColor, cCount);
    } catch (e) {
      debugPrint("Animation flight bypassed to preserve turn state.");
    }

    setState(() { 
      heldColor = null; 
      heldKilnIdx = null; 
      heldCount = null; 
      hoveredRow = null; 
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    socketService.send('PICK_TILES', {
      'code': widget.roomCode,
      'player': socketService.playerName ?? "",
      'kiln_idx': kIdx,
      'color': cColor,
      'target_row': targetRow
    });
  }

  void _playDraftingFlight(GlobalKey startKey, GlobalKey endKey, String color, int count) {
    final RenderBox? startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = endKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;

    final Offset startCenter = startBox.localToGlobal(Offset(startBox.size.width / 2, startBox.size.height / 2));
    final Offset endCenter = endBox.localToGlobal(Offset(endBox.size.width / 2, endBox.size.height / 2));
    double overlayWidth = count * 27.0;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayCtx) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutSine,
        builder: (BuildContext tweenCtx, double val, Widget? child) {
          double dx = startCenter.dx + (endCenter.dx - startCenter.dx) * val - (overlayWidth / 2);
          double dy = startCenter.dy + (endCenter.dy - startCenter.dy) * val - 13.5 - (math.sin(val * math.pi) * 60);
          return Positioned(
            left: dx, top: dy,
            child: Transform.scale(
              scale: val < 0.5 ? 1.0 + val * 0.3 : 1.3 - (val - 0.5) * 0.6,
              child: Row(
                mainAxisSize: MainAxisSize.min, 
                children: List.generate(count, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5), 
                  child: _buildTile(color, size: 24)
                ))
              )
            )
          );
        },
        onEnd: () => entry?.remove()
      )
    );
    Overlay.of(context)?.insert(entry!);
  }

  Color _getBaseColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue': return tTeal;
      case 'red': return tTerra;
      case 'yellow': return tGold;
      case 'black': return tInk;
      case 'amethyst': 
      case 'purple': 
      case 'white': return const Color(0xFF8E44AD); 
      default: return Colors.transparent;
    }
  }

  Widget _buildTile(String colorName, {double size = 20, double opacity = 1.0, bool isGhost = false, bool empty = false, double scale = 1.0}) {
    if (empty) return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)));
    Color bg = _getBaseColor(colorName);
    IconData? icon; 
    switch (colorName.toLowerCase()) {
      case 'blue': icon = Icons.star; break;
      case 'red': icon = Icons.menu; break;
      case 'yellow': icon = Icons.circle; break;
      case 'black': icon = Icons.close; break;
      case 'amethyst': 
      case 'purple': 
      case 'white': icon = Icons.diamond; break; 
      case 'first_player': 
        return Container(
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
          boxShadow: (opacity == 1.0 && !isGhost) ? [BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 3))] : []
        ),
        child: Center(child: Icon(icon, size: size * 0.45, color: Colors.white.withOpacity(0.5 * opacity))),
      ),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350), 
      switchInCurve: Curves.easeOutBack, 
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(scale: animation, child: child),
      child: Container(key: ValueKey(colorName + empty.toString() + isGhost.toString()), child: tile),
    );
  }

  Widget _buildBonusTrackers(List wall, {bool isOpp = false}) {
    int rows = 0; int cols = 0; int colors = 0;
    if (wall.isNotEmpty) {
      for (int r = 0; r < 5; r++) { if (wall[r].where((s) => s == "").isEmpty) rows++; }
      for (int c = 0; c < 5; c++) {
        bool full = true;
        for (int r = 0; r < 5; r++) { if (wall.length > r && wall[r].length > c && wall[r][c] == "") full = false; }
        if (full) cols++;
      }
      for (String color in ['blue', 'yellow', 'red', 'black', 'amethyst']) {
        int count = 0;
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) { 
            if (wall.length > r && wall[r].length > c) {
              String t = wall[r][c].toLowerCase();
              if (t == color || (color == 'amethyst' && (t == 'purple' || t == 'white'))) {
                count++;
              }
            }
          }
        }
        if (count == 5) colors++;
      }
    }
    double sz = isOpp ? 10 : 16;
    double fz = isOpp ? 10 : 14;
    return Padding(
      padding: EdgeInsets.only(top: isOpp ? 4 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu, size: sz, color: Colors.grey[400]), Text(" $rows", style: TextStyle(fontSize: fz, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          SizedBox(width: isOpp ? 6 : 12),
          Icon(Icons.view_column, size: sz, color: Colors.grey[400]), Text(" $cols", style: TextStyle(fontSize: fz, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          SizedBox(width: isOpp ? 6 : 12),
          Icon(Icons.diamond_outlined, size: sz, color: Colors.grey[400]), Text(" $colors", style: TextStyle(fontSize: fz, color: Colors.grey[500], fontWeight: FontWeight.bold)),
        ],
      )
    );
  }

  String? _getPlacementError(int rowIdx, String color, String player) {
    if (rowIdx == -1) return null;
    Map<String, dynamic> myBoard = _gameState['boards'][player] ?? {};
    List wall = myBoard['wall'] ?? [];
    List patternLines = myBoard['pattern_lines'] ?? [];

    for (int col = 0; col < 5; col++) {
      if (wall.length > rowIdx && wall[rowIdx].length > col && (wall[rowIdx][col] == color || (color == 'purple' && wall[rowIdx][col] == 'amethyst'))) {
        return "You've already built this color in that row!";
      }
    }
    if (patternLines.length > rowIdx) {
      for (var t in patternLines[rowIdx]) {
        if (t != "" && t != color && !(color == 'purple' && t == 'amethyst')) return "Row holds another color.";
      }
      if ((patternLines[rowIdx] as List).where((s) => s == "").isEmpty) return "Row is full!";
    }
    return null;
  }

  Widget _buildGameOverScreen() {
    List<String> ranked = List<String>.from((_gameState['boards'] as Map).keys);
    ranked.sort((a, b) => (_gameState['boards'][b]['score'] as int).compareTo(_gameState['boards'][a]['score'] as int));
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24), 
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: tGold),
            const SizedBox(height: 16),
            const Text("MATCH COMPLETE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: tInk)),
            const SizedBox(height: 32),
            ...ranked.map((p) {
              bool isWinner = p == ranked.first;
              int score = _gameState['boards'][p]['score'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 12, backgroundColor: tTeal, child: Text(p[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        Text(p, style: TextStyle(fontSize: 14, fontWeight: isWinner ? FontWeight.w900 : FontWeight.bold, color: tInk)),
                      ]
                    ),
                    Text(score.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isWinner ? tTeal : tInk)),
                  ]
                )
              );
            }).toList(),
            const SizedBox(height: 48),
            PhysicsButton(text: "REVIEW BOARDS", color: tIce, shadowColor: Colors.grey[400]!, onTap: () => setState(() => _isReviewingBoard = true)),
            const SizedBox(height: 16),
            PhysicsButton(text: "PLAY AGAIN", color: tTeal, shadowColor: const Color(0xFF1E7066), onTap: () => socketService.send('PLAY_AGAIN', {'code': widget.roomCode})),
            const SizedBox(height: 16),
            PhysicsButton(text: "EXIT TO LOBBY", color: tTerra, shadowColor: const Color(0xFFB3563F), onTap: () => socketService.send('RETURN_TO_LOBBY', {'code': widget.roomCode})),
          ]
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_gameState['status'] == "GAME_OVER" && !_isReviewingBoard) {
      return Scaffold(backgroundColor: tBg, body: SafeArea(child: _buildGameOverScreen()));
    }

    String myName = socketService.playerName ?? "";
    String turnPlayer = _gameState['turn_player'] ?? "";
    bool canPick = turnPlayer == myName && _gameState['status'] != "GAME_OVER";

    List<String> opponents = (_gameState['boards'] as Map).keys.where((p) => p != myName).map((e) => e.toString()).toList();
    
    Map<String, dynamic> myBoard = _gameState['boards'][myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    const List<String> shatterPenalties = ['-1', '-1', '-2', '-2', '-2', '-3', '-3'];

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Stack(
          children: [
            if (heldColor != null) 
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, 
                  onTap: () { 
                    setState(() { 
                      heldColor = null; 
                      heldKilnIdx = null; 
                      heldCount = null; 
                      hoveredRow = null; 
                    }); 
                  }
                )
              ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_gameState['status'] == "GAME_OVER")
                        const Text("REVIEWING BOARDS", style: TextStyle(color: tInk, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2))
                      else
                        Text(
                          turnPlayer == myName ? "YOUR TURN" : "OPPONENT: ${turnPlayer.toUpperCase()}", 
                          style: TextStyle(
                            color: turnPlayer == myName ? tTeal : tTerra, 
                            fontWeight: FontWeight.w900, 
                            fontSize: 12, 
                            letterSpacing: 2
                          )
                        ),
                      if (_gameState['status'] == "GAME_OVER")
                        GestureDetector(
                          onTap: () => setState(() => _isReviewingBoard = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: tTeal, borderRadius: BorderRadius.circular(12)),
                            child: const Text("RESULTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          )
                        )
                    ]
                  ),
                ),

                Expanded(
                  flex: 22, 
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: opponents.map((opp) {
                        var board = _gameState['boards'][opp] ?? {};
                        List oppWall = board['wall'] ?? [];
                        List oppFloor = board['floor_line'] ?? [];
                        List oppPattern = board['pattern_lines'] ?? [];
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4), 
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              borderRadius: BorderRadius.circular(12), 
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 10, 
                                            backgroundColor: tTeal, 
                                            child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
                                          ), 
                                          const SizedBox(width: 4), 
                                          Expanded(
                                            child: Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                                          )
                                        ]
                                      )
                                    ), 
                                    Text((board['score'] ?? 0).toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))
                                  ]
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end, 
                                          children: List.generate(5, (r) {
                                            return Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: List.generate(5, (cIdx) {
                                                if (cIdx < 4 - r) return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4); 
                                                int filled = ((oppPattern.length > r) ? oppPattern[r] as List : []).where((s) => s != "").length;
                                                String tileColor = filled > 0 ? (oppPattern[r] as List).firstWhere((s) => s != "") : "";
                                                return Container(
                                                  margin: const EdgeInsets.all(0.5), 
                                                  width: 4, height: 4, 
                                                  decoration: BoxDecoration(
                                                    color: (cIdx - (4 - r)) < (r + 1 - filled) ? Colors.grey[200] : _getBaseColor(tileColor), 
                                                    borderRadius: BorderRadius.circular(1)
                                                  )
                                                );
                                              })
                                            );
                                          })
                                        ),
                                        const SizedBox(width: 6),
                                        Column(
                                          children: List.generate(5, (r) {
                                            return Row(
                                              children: List.generate(5, (c) {
                                                String tile = (oppWall.length > r && oppWall[r].length > c) ? oppWall[r][c] : "";
                                                return Container(
                                                  margin: const EdgeInsets.all(0.5), 
                                                  width: 4, height: 4, 
                                                  decoration: BoxDecoration(
                                                    color: tile != "" ? _getBaseColor(tile) : _getBaseColor(wallPattern[r][c]).withOpacity(0.1), 
                                                    borderRadius: BorderRadius.circular(1)
                                                  )
                                                );
                                              })
                                            );
                                          })
                                        ),
                                      ]
                                    ),
                                  ),
                                ),
                                _buildBonusTrackers(oppWall, isOpp: true),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(7, (i) {
                                    String t = i < oppFloor.length ? oppFloor[i] : "";
                                    return _buildTile(t, size: 14, empty: t == "");
                                  })
                                )
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                ),

                Expanded(
                  flex: 33, 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(_gameState['factories'].length, (kIdx) {
                            List<String> fTiles = List<String>.from(_gameState['factories'][kIdx]);
                            fTiles.sort();
                            return Opacity(
                              opacity: fTiles.isEmpty || !canPick ? 0.2 : 1.0,
                              child: Container(
                                key: factoryKeys[kIdx], 
                                width: 54, height: 54, 
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Center(
                                  child: Wrap(
                                    spacing: 2, runSpacing: 2, 
                                    children: fTiles.map((c) {
                                      bool isHeldLocally = heldColor == c && heldKilnIdx == kIdx;
                                      return GestureDetector(
                                        onTap: !canPick ? null : () { 
                                          setState(() { heldColor = c; heldKilnIdx = kIdx; heldCount = fTiles.where((t) => t == c).length; }); 
                                          HapticFeedback.selectionClick();
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          transform: isHeldLocally ? Matrix4.translationValues(0, -6.0, 0) : Matrix4.identity(),
                                          child: _buildTile(c, size: 18)
                                        ),
                                      );
                                    }).toList()
                                  )
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        key: centerKey, 
                        constraints: const BoxConstraints(minHeight: 64), 
                        width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: const Color(0xFFE5E0D8), borderRadius: BorderRadius.circular(12)), 
                        child: Center(
                          child: (_gameState['center'] as List).isEmpty 
                              ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, color: Colors.grey)) 
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Wrap(
                                    spacing: 4, runSpacing: 4, 
                                    children: List<String>.from(_gameState['center']).map((c) {
                                      bool isHeldLocally = heldColor == c && heldKilnIdx == -1;
                                      return GestureDetector(
                                        onTap: (c == "first_player" || !canPick) ? null : () { 
                                          setState(() { heldColor = c; heldKilnIdx = -1; heldCount = (List<String>.from(_gameState['center'])).where((t) => t == c).length; }); 
                                          HapticFeedback.selectionClick();
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          transform: isHeldLocally ? Matrix4.translationValues(0, -4.0, 0) : Matrix4.identity(),
                                          child: _buildTile(c, size: 22)
                                        )
                                      );
                                    }).toList()
                                  ),
                                )
                        ),
                      )
                    ],
                  )
                ),

                Expanded(
                  flex: 45, 
                  child: Container(
                    color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                          children: [
                            const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text("SCORE: " + (myBoard['score'] ?? 0).toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal))
                          ]
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.contain, 
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(5, (rIdx) {
                                    String? errorMsg = heldColor != null ? _getPlacementError(rIdx, heldColor!, myName) : null;
                                    bool isLegal = heldColor != null && canPick && errorMsg == null;
                                    return GestureDetector(
                                      onTap: heldColor != null && canPick ? () {
                                        if (isLegal) _commitTurn(rIdx);
                                        else {
                                          HapticFeedback.vibrate();
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: tTerra));
                                        }
                                      } : null,
                                      onPanUpdate: (_) => setState(() => hoveredRow = rIdx),
                                      child: Container(
                                        key: patternRowKeys[rIdx], margin: const EdgeInsets.symmetric(vertical: 2), color: Colors.transparent,
                                        child: Row(
                                          children: List.generate(5, (cIdx) {
                                            if (cIdx < 4 - rIdx) return Container(width: 24, height: 24, margin: const EdgeInsets.all(1.5)); 
                                            int slotIdx = cIdx - (4 - rIdx);
                                            int filled = (patternLines[rIdx] as List).where((s) => s != "").length;
                                            String rowColor = filled > 0 ? (patternLines[rIdx] as List).firstWhere((s) => s.toString().isNotEmpty).toString() : "";
                                            int emptyCount = (rIdx + 1) - filled;
                                            int ghostStart = emptyCount;
                                            if (hoveredRow == rIdx && isLegal && heldCount != null) ghostStart = math.max(0, emptyCount - heldCount!);

                                            Widget tileW;
                                            if (slotIdx < ghostStart) tileW = _buildTile("", size: 24, empty: true);
                                            else if (slotIdx >= ghostStart && slotIdx < emptyCount) tileW = _buildTile(heldColor!, size: 24, isGhost: true);
                                            else tileW = _buildTile(rowColor, size: 24);

                                            return SizedBox(width: 27, height: 27, child: Center(child: tileW));
                                          }),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(width: 24), 
                                Column(
                                  children: List.generate(5, (rIdx) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: List.generate(5, (cIdx) {
                                          String t = (wall.length > rIdx && wall[rIdx].length > cIdx) ? wall[rIdx][cIdx] : "";
                                          return SizedBox(
                                            key: wallKeys[rIdx][cIdx], width: 27, height: 27, 
                                            child: Center(
                                                child: t != "" 
                                                  ? _buildTile(t, size: 24) 
                                                  : _buildTile(wallPattern[rIdx][cIdx], size: 24, opacity: 0.1)
                                            )
                                          );
                                        }),
                                      ),
                                    );
                                  }),
                                )
                              ],
                            ),
                          ),
                        ),
                        _buildBonusTrackers(wall),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: heldColor != null && canPick ? () => _commitTurn(-1) : null,
                          onPanUpdate: (_) => setState(() => hoveredRow = -1),
                          child: Container(
                            key: floorKey, 
                            padding: const EdgeInsets.all(4), 
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: hoveredRow == -1 ? tTeal : Colors.transparent, width: 2)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(7, (i) {
                                String t = i < floor.length ? floor[i] : "";
                                if (hoveredRow == -1 && heldColor != null && heldCount != null && i >= floor.length && i < floor.length + heldCount!) t = heldColor!;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4), 
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min, 
                                    children: [
                                      SizedBox(width: 27, height: 27, child: Center(child: _buildTile(t, size: 24, empty: t == "", isGhost: hoveredRow == -1 && t == heldColor))), 
                                      const SizedBox(height: 4), 
                                      Text(shatterPenalties[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tTerra))
                                    ]
                                  )
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}