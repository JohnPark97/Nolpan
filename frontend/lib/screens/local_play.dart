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
  List<String> _localPlayers = ["Player 1"];
  bool _isAddingPlayer = false;
  final TextEditingController _nameCtrl = TextEditingController();

  final List<Color> _avatarColors = [tTeal, tTerra, tGold, tInk];

  // GAME ENGINE STATE
  Map<String, dynamic> _gameState = {};
  String _turnPlayer = "";
  
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
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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

    bool roundOver = factories.every((f) => f.isEmpty) && center.where((t) => t != "first_player").isEmpty;

    if (roundOver) {
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
      
      // 1. Positive Points
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

      // 2. Penalties
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

      // 3. Clamp
      if (board['score'] < 0) board['score'] = 0;
      board['floor_line'] = [];
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

  Widget _buildLobby() {
    bool canStart = _localPlayers.length >= 2;

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
            const Icon(Icons.people, size: 48, color: tTeal),
            const SizedBox(height: 16),
            const Text("PASS & PLAY LOBBY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: tInk)),
            const SizedBox(height: 32),
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  if (i < _localPlayers.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 20, 
                            backgroundColor: _avatarColors[i % 4], 
                            child: Text(_localPlayers[i][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          ),
                          const SizedBox(height: 4),
                          Text(_localPlayers[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tInk))
                        ],
                      ),
                    );
                  } else if (i == _localPlayers.length && _localPlayers.length < 4) {
                    if (_isAddingPlayer) {
                      return Container(
                        width: 100, height: 40, margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: TextField(
                          controller: _nameCtrl,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(0),
                            hintText: "Name",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF8E44AD), width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF8E44AD), width: 2)),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              setState(() { 
                                _localPlayers.add(val.trim()); 
                                _isAddingPlayer = false; 
                                _nameCtrl.clear(); 
                              });
                            }
                          },
                        ),
                      );
                    } else {
                      return GestureDetector(
                        onTap: () => setState(() => _isAddingPlayer = true),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6), 
                          width: 40, height: 40, 
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle, 
                            color: Color(0xFF8E44AD), // SPRINT 16.2: Amethyst Pop
                            boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]
                          ), 
                          child: const Icon(Icons.add, color: Colors.white, size: 24)
                        ),
                      );
                    }
                  } else {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6), 
                      width: 40, height: 40, 
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        color: Colors.transparent, // SPRINT 16.2: Hollow Slot
                        border: Border.all(color: Colors.grey[400]!, width: 2)
                      )
                    );
                  }
                }),
              ),
            ),
            const SizedBox(height: 48),
            // SPRINT 16.2: Proper Grey Disabled State
            PhysicsButton(
              text: "START MATCH", 
              color: canStart ? tTeal : Colors.grey[300]!, 
              shadowColor: canStart ? const Color(0xFF1E7066) : Colors.grey[400]!,
              onTap: () { if (canStart) _startLocalGame(); }
            )
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_inLobby) {
      return Scaffold(
        backgroundColor: tBg, 
        body: SafeArea(child: _buildLobby())
      );
    }

    List<String> opponents = _localPlayers.where((p) => p != _turnPlayer).toList();
    Map<String, dynamic> myBoard = _gameState['boards'][_turnPlayer] ?? {};
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
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300), 
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child: Container(
                          key: ValueKey(_turnPlayer),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _avatarColors[_localPlayers.indexOf(_turnPlayer) % 4], 
                            borderRadius: BorderRadius.circular(12), 
                            boxShadow: [const BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]
                          ),
                          child: Text(
                            "TURN: " + _turnPlayer.toUpperCase(), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)
                          ),
                        )
                      ),
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
                            List<String> fTiles = _gameState['factories'][kIdx];
                            return Opacity(
                              opacity: fTiles.isEmpty ? 0.2 : 1.0,
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
                                        onTap: () { 
                                          setState(() { 
                                            heldColor = c; 
                                            heldKilnIdx = kIdx; 
                                            heldCount = fTiles.where((t) => t == c).length; 
                                          }); 
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150), curve: Curves.easeOutBack,
                                          transform: isHeldLocally ? Matrix4.translationValues(0, -4.0, 0) : Matrix4.identity(),
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
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Wrap(
                                    spacing: 4, runSpacing: 4, 
                                    children: (_gameState['center'] as List<String>).map((c) {
                                      bool isHeldLocally = heldColor == c && heldKilnIdx == -1;
                                      return GestureDetector(
                                        onTap: c == "first_player" ? null : () { 
                                          setState(() { 
                                            heldColor = c; 
                                            heldKilnIdx = -1; 
                                            heldCount = (_gameState['center'] as List).where((t) => t == c).length; 
                                          }); 
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150), curve: Curves.easeOutBack,
                                          transform: isHeldLocally ? Matrix4.translationValues(0, -4.0, 0) : Matrix4.identity(),
                                          child: _buildTile(c, size: 22, scale: isHeldLocally ? 1.1 : 1.0)
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
                                    bool isLegal = heldColor != null; 
                                    return GestureDetector(
                                      onTap: heldColor != null ? () => _commitTurn(rIdx) : null,
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
                                            if (slotIdx < ghostStart) tileW = _buildTile("", size: 24, empty: true);
                                            else if (slotIdx >= ghostStart && slotIdx < emptyCount) tileW = _buildTile(heldColor!, size: 24, isGhost: true);
                                            else tileW = _buildTile(rowColor, size: 24);

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
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: heldColor != null ? () => _commitTurn(-1) : null,
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