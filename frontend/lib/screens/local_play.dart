import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../main.dart';

const List<List<String>> wallPattern = [
  ['blue', 'yellow', 'red', 'black', 'amethyst'],
  ['amethyst', 'blue', 'yellow', 'red', 'black'],
  ['black', 'amethyst', 'blue', 'yellow', 'red'],
  ['red', 'black', 'amethyst', 'blue', 'yellow'],
  ['yellow', 'red', 'black', 'amethyst', 'blue'],
];

class LocalPlayScreen extends StatefulWidget {
  const LocalPlayScreen({super.key});
  @override
  State<LocalPlayScreen> createState() => _LocalPlayScreenState();
}

class _LocalPlayScreenState extends State<LocalPlayScreen> {
  // LOBBY STATE
  bool _inLobby = true;
  List<String> _localPlayers = [];
  bool _isAddingPlayer = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  final List<Color> _avatarColors = [tTeal, tTerra, tGold, tInk];

  // GAME ENGINE STATE
  Map<String, dynamic> _gameState = {};
  String _turnPlayer = "";
  bool _isReviewingBoard = false;
  
  // PHYSICS STATE
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
    // SPRINT 16.6: Invisible Overlay Focus Listener
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus && !_isAddingPlayer) {
        setState(() => _isAddingPlayer = true);
      } else if (!_nameFocusNode.hasFocus && _isAddingPlayer) {
        _submitName();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _submitName() {
    if (!mounted) return;
    String val = _nameCtrl.text.trim();
    setState(() {
      if (val.isNotEmpty && _localPlayers.length < 4) {
        _localPlayers.add(val);
      }
      _isAddingPlayer = false;
      _nameCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _startLocalGame() {
    FocusScope.of(context).unfocus();
    List<String> bag = [];
    for (String c in ["blue", "yellow", "red", "black", "purple"]) {
      for (int i = 0; i < 20; i++) bag.add(c);
    }
    bag.shuffle();

    Map<String, dynamic> boards = {};
    for (String p in _localPlayers) {
      boards[p] = {
        'score': 0, 'wins': 0,
        'pattern_lines': List.generate(5, (i) => List.filled(i + 1, "")),
        'wall': List.generate(5, (i) => List.filled(5, "")),
        'floor_line': <String>[]
      };
    }

    _gameState = {
      'factories': List.generate(5, (i) => <String>[]),
      'center': ["first_player"],
      'turn_player': _localPlayers[0],
      'center_has_first_player': true,
      'boards': boards,
      'bag': bag,
      'discard': <String>[],
      'status': "PLAYING",
      'last_scored': <String, dynamic>{},
    };

    _turnPlayer = _localPlayers[0];
    _isReviewingBoard = false;
    _drawTilesForRound();
    setState(() => _inLobby = false);
  }

  void _drawTilesForRound() {
    List<String> bag = _gameState['bag'];
    List<String> discard = _gameState['discard'];
    List<List<String>> factories = _gameState['factories'];

    for (int i = 0; i < factories.length; i++) {
      while (factories[i].length < 4) {
        if (bag.isEmpty) {
          if (discard.isEmpty) break;
          bag.addAll(discard);
          discard.clear();
          bag.shuffle();
        }
        factories[i].add(bag.removeLast());
      }
    }
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

  void _commitTurn(int targetRow) async {
    if (heldColor == null || heldKilnIdx == null) return;
    HapticFeedback.mediumImpact();
    
    String cColor = heldColor!;
    int kIdx = heldKilnIdx!;
    int cCount = heldCount!;
    String player = _turnPlayer;

    GlobalKey sourceKey = kIdx == -1 ? centerKey : factoryKeys[kIdx];
    GlobalKey destKey = targetRow == -1 ? floorKey : patternRowKeys[targetRow];
    _playDraftingFlight(sourceKey, destKey, cColor, cCount);

    setState(() { 
      heldColor = null; 
      heldKilnIdx = null; 
      heldCount = null; 
      hoveredRow = null; 
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    List<List<String>> factories = _gameState['factories'];
    List<String> center = _gameState['center'];
    Map<String, dynamic> b = _gameState['boards'][player];

    int picked = 0;
    if (kIdx >= 0) {
      List<String> remaining = [];
      for (String t in factories[kIdx]) {
        if (t == cColor) picked++; else center.add(t);
      }
      factories[kIdx] = [];
    } else {
      List<String> newCenter = [];
      for (String t in center) {
        if (t == cColor) {
          picked++;
        } else if (t == "first_player") {
          if (b['floor_line'].length < 7) {
            b['floor_line'].add("first_player");
          } else {
            _gameState['discard'].add("first_player");
          }
        } else {
          newCenter.add(t);
        }
      }
      _gameState['center'] = newCenter;
    }

    if (targetRow >= 0) {
      List<String> rTiles = b['pattern_lines'][targetRow];
      int emptySlots = rTiles.where((s) => s == "").length;
      for (int i = 0; i < picked; i++) {
        if (emptySlots > 0) {
          for (int j = 0; j < rTiles.length; j++) {
            if (rTiles[j] == "") { 
              rTiles[j] = cColor; 
              emptySlots--; 
              break; 
            }
          }
        } else {
          if (b['floor_line'].length < 7) {
            b['floor_line'].add(cColor);
          } else {
            _gameState['discard'].add(cColor);
          }
        }
      }
    } else {
      for (int i = 0; i < picked; i++) {
        if (b['floor_line'].length < 7) {
          b['floor_line'].add(cColor);
        } else {
          _gameState['discard'].add(cColor);
        }
      }
    }

    bool isMarketEmpty = true;
    for (var f in _gameState['factories']) {
      if ((f as List).isNotEmpty) { isMarketEmpty = false; break; }
    }
    if (isMarketEmpty) {
      for (var t in _gameState['center']) {
        if (t != "first_player") { isMarketEmpty = false; break; }
      }
    }

    if (isMarketEmpty) {
      _scoreRound();
    } else {
      int currIdx = _localPlayers.indexOf(player);
      setState(() => _turnPlayer = _localPlayers[(currIdx + 1) % _localPlayers.length]);
    }
  }

  void _scoreRound() async {
    Map<String, dynamic> b = _gameState['boards'][_turnPlayer];
    List<int> validScoringRows = [];
    for (int r = 0; r < 5; r++) {
      if (b['pattern_lines'][r].where((s) => s == "").isEmpty && b['pattern_lines'][r].isNotEmpty) {
        validScoringRows.add(r);
      }
    }

    for (int r in validScoringRows) {
      String color = b['pattern_lines'][r][0];
      int targetCol = wallPattern[r].indexOf(color == 'purple' ? 'amethyst' : color);
      if (targetCol != -1) _playScoringFlight(r, targetCol, color);
    }

    setState(() => _showShatter = true);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    for (String p in _localPlayers) {
      var board = _gameState['boards'][p];
      
      for (int r = 0; r < 5; r++) {
        if (board['pattern_lines'][r].where((s) => s == "").isEmpty && board['pattern_lines'][r].isNotEmpty) {
          String color = board['pattern_lines'][r][0];
          int tCol = wallPattern[r].indexOf(color == 'purple' ? 'amethyst' : color);
          if (tCol != -1) {
            board['wall'][r][tCol] = color;
            int hScore = 1;
            for (int j = tCol - 1; j >= 0 && board['wall'][r][j] != ""; j--) hScore++;
            for (int j = tCol + 1; j < 5 && board['wall'][r][j] != ""; j++) hScore++;
            int vScore = 1;
            for (int i = r - 1; i >= 0 && board['wall'][i][tCol] != ""; i--) vScore++;
            for (int i = r + 1; i < 5 && board['wall'][i][tCol] != ""; i++) vScore++;
            int pts = 0;
            if (hScore > 1 && vScore > 1) {
              pts = hScore + vScore;
            } else if (hScore > 1) {
              pts = hScore;
            } else if (vScore > 1) {
              pts = vScore;
            } else {
              pts = 1;
            }
            board['score'] += pts;
          }
          for (int i = 0; i < r; i++) _gameState['discard'].add(color);
          for (int c = 0; c <= r; c++) board['pattern_lines'][r][c] = "";
        }
      }

      List<int> pens = [-1, -1, -2, -2, -2, -3, -3];
      for (int i = 0; i < board['floor_line'].length; i++) {
        String t = board['floor_line'][i];
        if (t == "first_player") {
          _gameState['turn_player'] = p;
        } else {
          _gameState['discard'].add(t);
        }
        if (i < pens.length) {
          board['score'] += pens[i]; 
        } else {
          board['score'] -= 3;
        }
      }

      if (board['score'] < 0) board['score'] = 0;
      board['floor_line'] = [];
    }

    bool isGameOver = false;
    for (String p in _localPlayers) {
      var board = _gameState['boards'][p];
      for (int r = 0; r < 5; r++) {
        bool rowComplete = true;
        for (int c = 0; c < 5; c++) {
          if (board['wall'][r][c] == "") { rowComplete = false; break; }
        }
        if (rowComplete) { isGameOver = true; break; }
      }
    }

    if (isGameOver) {
      _gameState['status'] = "GAME_OVER";
      for (String p in _localPlayers) {
        var b = _gameState['boards'][p];
        
        for (int r = 0; r < 5; r++) {
          bool rowComplete = true;
          for (int c = 0; c < 5; c++) {
            if (b['wall'][r][c] == "") { rowComplete = false; break; }
          }
          if (rowComplete) b['score'] += 2;
        }
        
        for (int c = 0; c < 5; c++) {
          bool colComplete = true;
          for (int r = 0; r < 5; r++) {
            if (b['wall'][r][c] == "") { colComplete = false; break; }
          }
          if (colComplete) b['score'] += 7;
        }
        
        for (String color in ['blue', 'yellow', 'red', 'black', 'amethyst']) {
          int count = 0;
          for (int r = 0; r < 5; r++) {
            for (int c = 0; c < 5; c++) {
              String t = b['wall'][r][c].toLowerCase();
              if (t == color || (color == 'amethyst' && (t == 'purple' || t == 'white'))) count++;
            }
          }
          if (count == 5) b['score'] += 10;
        }
      }
      setState(() { _showShatter = false; });
      return;
    }

    _gameState['center'] = ["first_player"];
    _drawTilesForRound();
    setState(() {
      _turnPlayer = _gameState['turn_player'];
      _showShatter = false;
    });
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
          return Positioned(
            left: startPos.dx + (endPos.dx - startPos.dx) * val, 
            top: startPos.dy + (endPos.dy - startPos.dy) * val, 
            child: _buildTile(color, size: 24)
          );
        },
        onEnd: () => entry?.remove()
      )
    );
    Overlay.of(context)?.insert(entry!);
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

  Widget _buildLobby() {
    bool canStart = _localPlayers.length >= 2;

    // SPRINT 16.6: Top-Level Unfocus Detector to enable clicking away to save
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Center(
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
              const Icon(Icons.people, size: 48, color: tTeal),
              const SizedBox(height: 16),
              const Text("OFFLINE LOBBY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: tInk)),
              const SizedBox(height: 32),
              SizedBox(
                height: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(4, (i) {
                    if (i < _localPlayers.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 20, 
                                  backgroundColor: _avatarColors[i % 4], 
                                  child: Text(_localPlayers[i][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                ),
                                Positioned(
                                  right: -4, top: -4,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _localPlayers.removeAt(i)),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.remove_circle, color: tTerra, size: 16)
                                    )
                                  )
                                )
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(_localPlayers[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tInk))
                          ],
                        ),
                      );
                    } else if (i == _localPlayers.length && _localPlayers.length < 4) {
                      // SPRINT 16.6: Invisible Overlay Input Trick
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              width: _isAddingPlayer ? 100 : 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _isAddingPlayer ? Colors.white : const Color(0xFF8E44AD),
                                borderRadius: BorderRadius.circular(20),
                                border: _isAddingPlayer ? Border.all(color: const Color(0xFF8E44AD), width: 2) : null,
                                boxShadow: _isAddingPlayer ? [] : [const BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedOpacity(
                                    opacity: _isAddingPlayer ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 150),
                                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                                  ),
                                  TextField(
                                    controller: _nameCtrl,
                                    focusNode: _nameFocusNode,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.bold, 
                                      color: _isAddingPlayer ? tInk : Colors.transparent
                                    ),
                                    cursorColor: _isAddingPlayer ? const Color(0xFF8E44AD) : Colors.transparent,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.only(bottom: 12),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      hintText: _isAddingPlayer ? "Name" : "",
                                      hintStyle: TextStyle(color: _isAddingPlayer ? Colors.grey : Colors.transparent, fontSize: 12),
                                    ),
                                    onSubmitted: (_) => _submitName(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text("", style: TextStyle(fontSize: 10))
                          ],
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40, height: 40, 
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, 
                                color: Colors.transparent, 
                                border: Border.all(color: Colors.grey[400]!, width: 2)
                              )
                            ),
                            const SizedBox(height: 4),
                            const Text("", style: TextStyle(fontSize: 10))
                          ]
                        )
                      );
                    }
                  }),
                ),
              ),
              const SizedBox(height: 48),
              PhysicsButton(
                text: "START MATCH", 
                color: canStart ? tTeal : Colors.grey[300]!, 
                shadowColor: canStart ? const Color(0xFF1E7066) : Colors.grey[400]!,
                onTap: () { if (canStart) _startLocalGame(); }
              )
            ],
          )
        )
      ),
    );
  }

  Widget _buildGameOverScreen() {
    List<String> ranked = List.from(_localPlayers);
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
                        CircleAvatar(radius: 12, backgroundColor: _avatarColors[_localPlayers.indexOf(p) % 4], child: Text(p[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
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
            PhysicsButton(text: "PLAY AGAIN", color: tTeal, shadowColor: const Color(0xFF1E7066), onTap: _startLocalGame),
            const SizedBox(height: 16),
            PhysicsButton(text: "EXIT TO LOBBY", color: tTerra, shadowColor: const Color(0xFFB3563F), onTap: () => setState(() { _inLobby = true; _isReviewingBoard = false; })),
          ]
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_inLobby) {
      return Scaffold(backgroundColor: tBg, body: SafeArea(child: _buildLobby()));
    }

    if (_gameState['status'] == "GAME_OVER" && !_isReviewingBoard) {
      return Scaffold(backgroundColor: tBg, body: SafeArea(child: _buildGameOverScreen()));
    }

    List<String> opponents = _localPlayers.where((p) => p != _turnPlayer).toList();
    Map<String, dynamic> myBoard = _gameState['boards'][_turnPlayer] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    const List<String> shatterPenalties = ['-1', '-1', '-2', '-2', '-2', '-3', '-3'];

    bool canPick = _gameState['status'] != "GAME_OVER";

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
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_gameState['status'] == "GAME_OVER")
                        const Text("REVIEWING BOARDS", style: TextStyle(color: tInk, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2))
                      else
                        Text(
                          "CURRENT TURN: ${_turnPlayer.toUpperCase()}", 
                          style: TextStyle(
                            color: _avatarColors[_localPlayers.indexOf(_turnPlayer) % 4], 
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
                      else
                        IconButton(icon: const Icon(Icons.settings, color: Colors.transparent, size: 24), onPressed: null)
                    ]
                  ),
                ),

                // Opponents
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
                                            backgroundColor: _avatarColors[_localPlayers.indexOf(opp) % 4], 
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
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2), width: 14, height: 14, 
                                      decoration: BoxDecoration(color: t != "" ? _getBaseColor(t) : Colors.grey[200], borderRadius: BorderRadius.circular(2))
                                    );
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

                // Center/Factories
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
                                      bool dim = heldKilnIdx == kIdx && !isHeldLocally;
                                      return GestureDetector(
                                        onTap: !canPick ? null : () { 
                                          setState(() { 
                                            heldColor = c; 
                                            heldKilnIdx = kIdx; 
                                            heldCount = fTiles.where((t) => t == c).length; 
                                          }); 
                                          HapticFeedback.selectionClick();
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150), curve: Curves.easeOutBack,
                                          transform: isHeldLocally ? Matrix4.translationValues(0, -6.0, 0) : Matrix4.identity(),
                                          child: _buildTile(c, size: 18, opacity: dim ? 0.3 : 1.0, scale: isHeldLocally ? 1.1 : 1.0)
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
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E0D8), 
                          borderRadius: BorderRadius.circular(12), 
                          border: const Border(top: BorderSide(color: Colors.black12, width: 2))
                        ), 
                        child: Center(
                          child: (_gameState['center'] as List).isEmpty 
                              ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, color: Colors.grey)) 
                              : Builder(builder: (context) {
                                  List<String> sortedCenter = List<String>.from(_gameState['center']);
                                  sortedCenter.sort((a, b) {
                                    if (a == "first_player") return -1;
                                    if (b == "first_player") return 1;
                                    return a.compareTo(b);
                                  });
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Wrap(
                                      spacing: 4, runSpacing: 4, 
                                      children: sortedCenter.map((c) {
                                        bool isHeldLocally = heldColor == c && heldKilnIdx == -1;
                                        return GestureDetector(
                                          onTap: (c == "first_player" || !canPick) ? null : () { 
                                            setState(() { 
                                              heldColor = c; 
                                              heldKilnIdx = -1; 
                                              heldCount = sortedCenter.where((t) => t == c).length; 
                                            }); 
                                            HapticFeedback.selectionClick();
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150), curve: Curves.easeOutBack,
                                            transform: isHeldLocally ? Matrix4.translationValues(0, -4.0, 0) : Matrix4.identity(),
                                            child: _buildTile(c, size: 22, scale: isHeldLocally ? 1.1 : 1.0)
                                          )
                                        );
                                      }).toList()
                                    ),
                                  );
                                })
                        ),
                      )
                    ],
                  )
                ),

                // My Workshop
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
                                    String? errorMsg = heldColor != null ? _getPlacementError(rIdx, heldColor!, _turnPlayer) : null;
                                    bool isLegal = heldColor != null && canPick && errorMsg == null;
                                    
                                    return GestureDetector(
                                      onTap: heldColor != null && canPick ? () {
                                        if (isLegal) {
                                          _commitTurn(rIdx);
                                        } else {
                                          HapticFeedback.vibrate();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(errorMsg!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: tTerra, duration: const Duration(seconds: 2))
                                          );
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
                                            if (hoveredRow == rIdx && isLegal && heldCount != null) {
                                              ghostStart = math.max(0, emptyCount - heldCount!);
                                            }

                                            Widget tileW;
                                            if (slotIdx < ghostStart) {
                                              tileW = _buildTile("", size: 24, empty: true);
                                            } else if (slotIdx >= ghostStart && slotIdx < emptyCount) {
                                              tileW = _buildTile(heldColor!, size: 24, isGhost: true);
                                            } else {
                                              tileW = _buildTile(rowColor, size: 24);
                                            }

                                            if (_showShatter) {
                                              tileW = AnimatedScale(
                                                scale: 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInBack, 
                                                child: AnimatedOpacity(opacity: 0.0, duration: const Duration(milliseconds: 400), child: tileW)
                                              );
                                            }
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
                                            key: wallKeys[rIdx][cIdx], width: 27, height: 27, 
                                            child: Stack(
                                              alignment: Alignment.center, 
                                              children: [
                                                Positioned(
                                                  child: t != "" 
                                                    ? _buildTile(t, size: 24) 
                                                    : _buildTile(wallPattern[rIdx][cIdx], size: 24, isGhost: true)
                                                )
                                              ]
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
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8), 
                              border: Border.all(color: hoveredRow == -1 ? tTeal : Colors.transparent, width: 2)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(7, (i) {
                                String t = i < floor.length ? floor[i] : "";
                                if (hoveredRow == -1 && heldColor != null && heldCount != null && i >= floor.length && i < floor.length + heldCount!) {
                                  t = heldColor!;
                                }
                                Widget tileW = _buildTile(t, size: 24, empty: t == "", isGhost: hoveredRow == -1 && t == heldColor);
                                if (_showShatter && t != "") {
                                  tileW = AnimatedScale(
                                    scale: 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInBack, 
                                    child: AnimatedOpacity(opacity: 0.0, duration: const Duration(milliseconds: 400), child: tileW)
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4), 
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min, 
                                    children: [
                                      SizedBox(width: 27, height: 27, child: Stack(alignment: Alignment.center, children:[Positioned(child: tileW)])), 
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