import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../main.dart';
import '../../../core/ui/physics_button.dart';
import 'lobby.dart';

const List<List<String>> wallPattern = [
  ['blue', 'yellow', 'red', 'black', 'amethyst'],
  ['amethyst', 'blue', 'yellow', 'red', 'black'],
  ['black', 'amethyst', 'blue', 'yellow', 'red'],
  ['red', 'black', 'amethyst', 'blue', 'yellow'],
  ['yellow', 'red', 'black', 'amethyst', 'blue'],
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
  Map<String, dynamic>? activeSelection;
  String? turnPlayer;
  late StreamSubscription _sub;

  String? heldColor;
  int? heldKilnIdx;
  int? heldCount;
  int? hoveredRow;

  final List<GlobalKey> factoryKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey centerKey = GlobalKey();
  final List<GlobalKey> patternRowKeys = List.generate(5, (_) => GlobalKey());
  final List<List<GlobalKey>> wallKeys = List.generate(5, (_) => List.generate(5, (_) => GlobalKey()));
  final GlobalKey floorKey = GlobalKey();

  bool _isWaitingForServer = false;
  bool _showShatter = false;
  bool _isGameOver = false;
  bool _isReviewingBoard = false;

  @override
  void initState() {
    super.initState();
    _updateState(widget.initialState);
    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'GAME_UPDATE') {
        _handleIncomingState(msg['payload'], isGameOver: false);
      } else if (msg['type'] == 'GAME_OVER') {
        _handleIncomingState(msg['payload'], isGameOver: true);
      } else if (msg['type'] == 'GAME_STARTED') {
        if (mounted) {
          setState(() { _isGameOver = false; _isReviewingBoard = false; _showShatter = false; });
          _updateState(msg['payload']);
        }
      } else if (msg['type'] == 'RETURN_TO_LOBBY') {
        if (mounted) {
          _sub.cancel();
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LobbyScreen()), (route) => false);
        }
      }
    });
  }

  void _handleIncomingState(Map<String, dynamic> payload, {bool isGameOver = false}) async {
    if (boards == null || payload['factories'] == null) {
      _updateState(payload);
      if (isGameOver && mounted) setState(() => _isGameOver = true);
      return;
    }

    bool oldEmpty = factories!.every((f) => f.isEmpty);
    bool newFull = (payload['factories'] as List).isNotEmpty && (payload['factories'][0] as List).isNotEmpty;

    if (oldEmpty && (newFull || isGameOver)) {
      String myName = socketService.playerName ?? "";
      List patternLines = boards![myName]?['pattern_lines'] ?? [];
      
      List<int> validScoringRows = [];
      for (int r = 0; r < 5; r++) {
        int emptySlots = (patternLines[r] as List).where((s) => s == "").length;
        if (emptySlots == 0 && (patternLines[r] as List).isNotEmpty && patternLines[r][0] != "") validScoringRows.add(r);
      }

      for (int r in validScoringRows) {
        String color = patternLines[r][0];
        int targetCol = wallPattern[r].indexOf(color == 'purple' ? 'amethyst' : color);
        if (targetCol != -1) _playScoringFlight(r, targetCol, color);
      }

      setState(() => _showShatter = true);
      HapticFeedback.heavyImpact();
      
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() { _showShatter = false; _updateState(payload); });
      if (isGameOver && mounted) setState(() => _isGameOver = true);
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
    activeSelection = Map<String, dynamic>.from(payload['active_selection'] ?? {});
    
    String newTurnPlayer = payload['turn_player'] ?? (boards!.isNotEmpty ? boards!.keys.first : "...");
    bool turnChanged = turnPlayer != newTurnPlayer;
    turnPlayer = newTurnPlayer;

    setState(() {
      if (turnChanged) { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; }
      _isWaitingForServer = false; 
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  String? _getPlacementError(int rowIdx, String color) {
    if (rowIdx == -1) return null; 
    String myName = socketService.playerName ?? "";
    Map<String, dynamic> myBoard = boards![myName] ?? {};
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

  void _broadcastHover(String? color, int? kilnIdx) {
    if (socketService.currentRoomCode != null) {
      socketService.send('HOVER_TILE', {
        'code': socketService.currentRoomCode,
        'name': socketService.playerName,
        'selection': color == null ? null : {'color': color, 'kiln_idx': kilnIdx}
      });
    }
  }

  void _commitTurn(int targetRow) {
    if (heldColor == null || heldKilnIdx == null) return;
    HapticFeedback.mediumImpact();
    String colorToFly = heldColor!;
    int kilnIdxToSend = heldKilnIdx!;
    int countToFly = heldCount!;
    
    GlobalKey sourceKey = kilnIdxToSend == -1 ? centerKey : factoryKeys[kilnIdxToSend];
    GlobalKey destKey = targetRow == -1 ? floorKey : patternRowKeys[targetRow];
    _playDraftingFlight(sourceKey, destKey, colorToFly, countToFly);

    setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; _isWaitingForServer = true; });
    _broadcastHover(null, null);

    if (socketService.currentRoomCode != null) {
      socketService.send('PICK_TILES', {
        'code': socketService.currentRoomCode,
        'player': socketService.playerName,
        'kiln_idx': kilnIdxToSend,
        'color': colorToFly,
        'target_row': targetRow
      });
    }
  }

  void _playScoringFlight(int r, int c, String color) {
    final RenderBox? startBox = patternRowKeys[r].currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = wallKeys[r][c].currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;

    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayCtx) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (BuildContext tweenCtx, double val, Widget? child) {
          return Positioned(left: startPos.dx + (endPos.dx - startPos.dx) * val, top: startPos.dy + (endPos.dy - startPos.dy) * val, child: _buildTile(color, size: 24));
        },
        onEnd: () => entry?.remove()
      )
    );
    Overlay.of(context).insert(entry!);
  }

  void _playDraftingFlight(GlobalKey startKey, GlobalKey endKey, String color, int count) {
    final RenderBox? startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = endKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;

    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayCtx) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutSine,
        builder: (BuildContext tweenCtx, double val, Widget? child) {
          double dx = startPos.dx + (endPos.dx - startPos.dx) * val;
          double dy = startPos.dy + (endPos.dy - startPos.dy) * val - (math.sin(val * math.pi) * 60);
          return Positioned(
            left: dx, top: dy,
            child: Transform.scale(
              scale: val < 0.5 ? 1.0 + val * 0.3 : 1.3 - (val - 0.5) * 0.6,
              child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(count, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: _buildTile(color, size: 24))))
            )
          );
        },
        onEnd: () => entry?.remove()
      )
    );
    Overlay.of(context).insert(entry!);
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
      case 'first_player': return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: const Color(0xFFF3E5AB), borderRadius: BorderRadius.circular(4), border: Border.all(color: tGold, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), offset: const Offset(0, 3))]), child: Center(child: Text("1", style: TextStyle(color: tGold, fontWeight: FontWeight.bold, fontSize: size * 0.5))));
    }
    Widget tile = Transform.scale(
      scale: scale,
      child: Container(
        width: size, height: size, margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(color: isGhost ? bg.withOpacity(0.15) : bg.withOpacity(opacity), borderRadius: BorderRadius.circular(4), boxShadow: (opacity == 1.0 && !isGhost) ? [BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 3))] : []),
        child: Center(child: Icon(icon, size: size * 0.45, color: Colors.white.withOpacity(0.5 * opacity))),
      ),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350), switchInCurve: Curves.easeOutBack, switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(scale: animation, child: child),
      child: Container(key: ValueKey(colorName + empty.toString() + isGhost.toString()), child: tile),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (factories == null || boards == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: tTeal)));
    String myName = socketService.playerName ?? "Player";
    bool isMyTurn = turnPlayer == myName && !_isWaitingForServer && !_isGameOver;
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
            if (heldColor != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; });
                    _broadcastHover(null, null);
                  }
                )
              ),
            
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 2)),
                      IconButton(icon: const Icon(Icons.settings, color: Colors.transparent, size: 24), onPressed: null)
                    ]
                  ),
                ),

                Expanded(
                  flex: 22,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: opponents.isEmpty
                        ? const Center(child: Text("WAITING FOR OPPONENTS...", style: TextStyle(fontSize: 10, color: Colors.grey)))
                        : Row(
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Row(children: [CircleAvatar(radius: 10, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))), const SizedBox(width: 4), Expanded(child: Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))])),
                                          Text("${board['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))
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
                                                children: List.generate(5, (r) => Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: List.generate(5, (cIdx) {
                                                    if (cIdx < 4 - r) return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4);
                                                    int filled = ((oppPattern.length > r) ? oppPattern[r] as List : []).where((s) => s != "").length;
                                                    String tileColor = filled > 0 ? (oppPattern[r] as List).firstWhere((s) => s != "") : "";
                                                    return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4, decoration: BoxDecoration(color: (cIdx - (4 - r)) < (r + 1 - filled) ? Colors.grey[200] : _getBaseColor(tileColor), borderRadius: BorderRadius.circular(1)));
                                                  })
                                                ))
                                              ),
                                              const SizedBox(width: 6),
                                              Column(
                                                children: List.generate(5, (r) => Row(
                                                  children: List.generate(5, (c) {
                                                    String tile = (oppWall.length > r && oppWall[r].length > c) ? oppWall[r][c] : "";
                                                    return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4, decoration: BoxDecoration(color: tile != "" ? _getBaseColor(tile) : _getBaseColor(wallPattern[r][c]).withOpacity(0.1), borderRadius: BorderRadius.circular(1)));
                                                  })
                                                ))
                                              ),
                                            ]
                                          ),
                                        ),
                                      ),
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
                  child: _isGameOver ? const SizedBox.shrink() : Opacity(
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
                                return Opacity(
                                  opacity: factories![kIdx].isEmpty ? 0.2 : 1.0,
                                  child: Container(
                                    key: factoryKeys[kIdx], width: 54, height: 54, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: Center(child: Wrap(spacing: 2, runSpacing: 2, children: factories![kIdx].map((c) {
                                      bool isHeldLocally = heldColor == c && heldKilnIdx == kIdx;
                                      bool isHeldByOpp = activeSelection?[turnPlayer]?['color'] == c && activeSelection?[turnPlayer]?['kiln_idx'] == kIdx && turnPlayer != myName;
                                      bool dim = (heldKilnIdx == kIdx || activeSelection?[turnPlayer]?['kiln_idx'] == kIdx) && !isHeldLocally && !isHeldByOpp;
                                      return GestureDetector(
                                        onTap: () { setState(() { heldColor = c; heldKilnIdx = kIdx; heldCount = factories![kIdx].where((t) => t == c).length; }); _broadcastHover(heldColor, heldKilnIdx); },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150), curve: Curves.easeOutBack,
                                          transform: isHeldLocally ? Matrix4.translationValues(0, -4.0, 0) : Matrix4.identity(),
                                          child: _buildTile(c, size: 18, opacity: dim ? 0.3 : 1.0, scale: isHeldLocally ? 1.1 : 1.0)
                                        ),
                                      );
                                    }).toList())),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            key: centerKey, constraints: const BoxConstraints(minHeight: 64), width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: const Color(0xFFE5E0D8), borderRadius: BorderRadius.circular(12), border: const Border(top: BorderSide(color: Colors.black12, width: 2))),
                            child: Center(child: center!.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, color: Colors.grey)) : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Wrap(spacing: 4, runSpacing: 4, children: center!.map((c) {
                                bool isHeldLocally = heldColor == c && heldKilnIdx == -1;
                                bool isHeldByOpp = activeSelection?[turnPlayer]?['color'] == c && activeSelection?[turnPlayer]?['kiln_idx'] == -1 && turnPlayer != myName;
                                return GestureDetector(
                                  onTap: c == "first_player" ? null : () { setState(() { heldColor = c; heldKilnIdx = -1; heldCount = center!.where((t) => t == c).length; }); _broadcastHover(heldColor, heldKilnIdx); },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150), curve: Curves.easeOutBack,
                                    transform: isHeldLocally ? Matrix4.translationValues(0, -4.0, 0) : Matrix4.identity(),
                                    child: _buildTile(c, size: 22, scale: isHeldLocally ? 1.1 : 1.0)
                                  )
                                );
                              }).toList()),
                            )),
                          )
                        ],
                      ),
                    ),
                  )
                ),

                Expanded(
                  flex: 45,
                  child: Container(
                    color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal))
                        ]),
                        const SizedBox(height: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(5, (rIdx) {
                                    String? errorMsg = heldColor != null ? _getPlacementError(rIdx, heldColor!) : null;
                                    bool isLegal = heldColor != null && errorMsg == null;
                                    return GestureDetector(
                                      onTap: heldColor != null ? () {
                                        if (isLegal) _commitTurn(rIdx);
                                        else { HapticFeedback.vibrate(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: tTerra, duration: const Duration(seconds: 2))); }
                                      } : null,
                                      onPanUpdate: (_) => setState(() => hoveredRow = rIdx),
                                      child: Container(
                                        key: patternRowKeys[rIdx],
                                        margin: const EdgeInsets.symmetric(vertical: 2), color: Colors.transparent,
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

                                            if (_showShatter) tileW = AnimatedScale(scale: 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInBack, child: AnimatedOpacity(opacity: 0.0, duration: const Duration(milliseconds: 400), child: tileW));

                                            return SizedBox(width: 27, height: 27, child: Stack(alignment: Alignment.center, children: [Positioned(child: tileW)]));
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
                                            key: wallKeys[rIdx][cIdx],
                                            width: 27, height: 27, child: Stack(alignment: Alignment.center, children: [Positioned(child: t != "" ? _buildTile(t, size: 24) : _buildTile(wallPattern[rIdx][cIdx], size: 24, isGhost: true))])
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
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: heldColor != null ? () => _commitTurn(-1) : null,
                          onPanUpdate: (_) => setState(() => hoveredRow = -1),
                          child: Container(
                            key: floorKey, padding: const EdgeInsets.all(4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: hoveredRow == -1 ? tTeal : Colors.transparent, width: 2)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(7, (i) {
                                String t = i < floor.length ? floor[i] : "";
                                if (hoveredRow == -1 && heldColor != null && heldCount != null && i >= floor.length && i < floor.length + heldCount!) t = heldColor!;
                                Widget tileW = _buildTile(t, size: 24, empty: t == "", isGhost: hoveredRow == -1 && t == heldColor);
                                if (_showShatter && t != "") tileW = AnimatedScale(scale: 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInBack, child: AnimatedOpacity(opacity: 0.0, duration: const Duration(milliseconds: 400), child: tileW));
                                return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 27, height: 27, child: Stack(alignment: Alignment.center, children:[Positioned(child: tileW)])), const SizedBox(height: 4), Text(shatterPenalties[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tTerra))]));
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