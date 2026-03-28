import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../main.dart';
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
  final GlobalKey floorKey = GlobalKey();

  bool _isAnimatingScoring = false;
  bool _isWaitingForServer = false;
  bool _showSlide = false;
  bool _showPop = false;
  bool _showShatter = false;

  bool _isGameOver = false;
  bool _isReviewingBoard = false;

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
      } else if (msg['type'] == 'GAME_STARTED') {
        if (mounted) {
          setState(() {
            _isGameOver = false;
            _isReviewingBoard = false;
            _isAnimatingScoring = false;
            _showSlide = false;
            _showPop = false;
            _showShatter = false;
            _scoringRows.clear();
            _incomingPayload = null;
          });
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
      _incomingPayload = payload;
      String myName = socketService.playerName ?? "";
      List patternLines = boards![myName]?['pattern_lines'] ?? [];
      
      List<int> validScoringRows = [];
      for (int r = 0; r < 5; r++) {
        int emptySlots = (patternLines[r] as List).where((s) => s == "").length;
        if (emptySlots == 0 && (patternLines[r] as List).isNotEmpty && patternLines[r][0] != "") validScoringRows.add(r);
      }

      setState(() { _isAnimatingScoring = true; _scoringRows = validScoringRows; _showSlide = true; _showShatter = true; });
      
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() { _showPop = true; });
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 600));
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
        setState(() => _isGameOver = true);
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
    activeSelection = Map<String, dynamic>.from(payload['active_selection'] ?? {});
    
    String newTurnPlayer = payload['turn_player'] ?? (boards!.isNotEmpty ? boards!.keys.first : "...");
    bool turnChanged = turnPlayer != newTurnPlayer;
    turnPlayer = newTurnPlayer;

    setState(() {
      if (turnChanged) {
        heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null;
      }
      _isWaitingForServer = false; 
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  String _capitalize(String s) => s.isNotEmpty ? "${s[0].toUpperCase()}${s.substring(1)}" : s;

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

  void _broadcastHover(String? color, int? kilnIdx) {
    if (socketService.currentRoomCode != null) {
      socketService.send('HOVER_TILE', {
        'code': socketService.currentRoomCode,
        'name': socketService.playerName,
        'selection': color == null ? null : {'color': color, 'kiln_idx': kilnIdx}
      });
    }
  }

  // TICKET #2 FIX: Removed UI-blocking Overlay Flight. Replaced with instantaneous data sync + CSS elastic Pop-In.
  void _commitTurn(int targetRow) {
    if (heldColor == null || heldKilnIdx == null) return;
    HapticFeedback.mediumImpact();
    String colorToFly = heldColor!;
    int kilnIdxToSend = heldKilnIdx!;
    
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
          boxShadow: (opacity == 1.0 && !isGhost) ? [BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 3))] : [],
        ),
        child: Center(child: Icon(icon, size: size * 0.45, color: Colors.white.withOpacity(0.5 * opacity))),
      ),
    );
    
    // TICKET #2 FIX: Elastic Cross-Fade Pop-In
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
          Icon(Icons.menu, size: sz, color: Colors.grey[400]), Text(" ${rows}", style: TextStyle(fontSize: fz, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          SizedBox(width: isOpp ? 6 : 12),
          Icon(Icons.view_column, size: sz, color: Colors.grey[400]), Text(" ${cols}", style: TextStyle(fontSize: fz, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          SizedBox(width: isOpp ? 6 : 12),
          Icon(Icons.diamond_outlined, size: sz, color: Colors.grey[400]), Text(" ${colors}", style: TextStyle(fontSize: fz, color: Colors.grey[500], fontWeight: FontWeight.bold)),
        ],
      )
    );
  }

  Widget _buildScoreStat(String label, String val) {
    return Expanded(
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const Spacer(),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, color: tInk, fontSize: 12)),
          const SizedBox(width: 12)
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (factories == null || boards == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: tTeal)));
    String myName = socketService.playerName ?? "Player";
    bool isMyTurn = turnPlayer == myName && !_isAnimatingScoring && !_isWaitingForServer && !_isGameOver;
    
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    List<String> opponents = boards!.keys.where((k) => k != myName).toList();
    const List<String> shatterPenalties = ['-1', '-1', '-2', '-2', '-2', '-3', '-3'];

    List<Map<String, dynamic>> finalScores = [];
    if (_isGameOver) {
      boards!.forEach((name, data) {
        int finalScore = data['score'] ?? 0;
        int wins = data['wins'] ?? 0;
        List bWall = data['wall'] ?? [];
        int rows = 0; int cols = 0; int colors = 0;
        if (bWall.isNotEmpty) {
          for (int r=0; r<5; r++) { if (bWall[r].where((s)=>s=="").isEmpty) rows++; }
          for (int c=0; c<5; c++) {
            bool full = true;
            for (int r=0; r<5; r++) { if (bWall[r][c] == "") full = false; }
            if (full) cols++;
          }
          for (String color in ['blue', 'yellow', 'red', 'black', 'amethyst']) {
            int count = 0;
            for (int r=0; r<5; r++) { 
              for (int c=0; c<5; c++) { 
                String t = bWall[r][c].toLowerCase();
                if (t == color || (color == 'amethyst' && (t == 'purple' || t == 'white'))) count++;
              }
            }
            if (count == 5) colors++;
          }
        }
        int baseScore = finalScore - (rows * 2) - (cols * 7) - (colors * 10);
        finalScores.add({ 'name': name, 'final': finalScore, 'base': baseScore, 'rows': rows * 2, 'cols': cols * 7, 'colors': colors * 10, 'wins': wins });
      });
      finalScores.sort((a, b) => (b['final'] as int).compareTo(a['final'] as int));
    }

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Stack(
          children: [
            if (heldColor != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; }); _broadcastHover(null, null); })),
            
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 2)),
                      IconButton(icon: const Icon(Icons.settings, color: Colors.transparent, size: 24), onPressed: null),
                    ],
                  ),
                ),

                Expanded(flex: 22, child: Container(
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(children: [
                                      CircleAvatar(radius: 10, backgroundColor: tTeal, child: Text(opp[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))), 
                                      const SizedBox(width: 4), 
                                      Expanded(child: Text(opp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))
                                    ])
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("${board['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                      if ((board['wins'] ?? 0) > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.emoji_events, size: 10, color: tGold),
                                            const SizedBox(width: 2),
                                            Text("${board['wins']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tGold)),
                                          ],
                                        )
                                    ],
                                  )
                                ]
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: List.generate(5, (r) => Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: List.generate(5, (cIdx) {
                                            if (cIdx < 4 - r) return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4); 
                                            int slotIdx = cIdx - (4 - r);
                                            int capacity = r + 1;
                                            List rowTiles = (oppPattern.length > r) ? oppPattern[r] : [];
                                            int filled = rowTiles.where((s) => s != "").length;
                                            int emptyCount = capacity - filled;
                                            String tileColor = filled > 0 ? rowTiles.firstWhere((s) => s != "") : "";

                                            if (slotIdx < emptyCount) return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(1)));
                                            else return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4, decoration: BoxDecoration(color: _getBaseColor(tileColor), borderRadius: BorderRadius.circular(1)));
                                          })
                                        ))
                                      ),
                                      const SizedBox(width: 6),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(5, (r) => Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(5, (c) {
                                            String tile = (oppWall.length > r && oppWall[r].length > c) ? oppWall[r][c] : "";
                                            Color bg = tile != "" ? _getBaseColor(tile) : _getBaseColor(wallPattern[r][c]).withOpacity(0.1);
                                            return Container(margin: const EdgeInsets.all(0.5), width: 4, height: 4, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(1)));
                                          })
                                        )),
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
                )),

                Expanded(flex: 33, child: (_isGameOver && _isReviewingBoard) ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("GAME OVER", style: TextStyle(fontWeight: FontWeight.w900, color: tTeal, fontSize: 24, letterSpacing: 2)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                side: BorderSide(color: Colors.grey[400]!, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () { if (socketService.currentRoomCode != null) socketService.send('RETURN_TO_LOBBY', {'code': socketService.currentRoomCode}); },
                              child: const Text("LOBBY", style: TextStyle(fontWeight: FontWeight.bold))
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD700),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () { if (socketService.currentRoomCode != null) socketService.send('PLAY_AGAIN', {'code': socketService.currentRoomCode}); },
                              child: const Text("PLAY AGAIN", style: TextStyle(fontWeight: FontWeight.bold))
                            )
                          ),
                        ]
                      )
                    ]
                  )
                ) : (_isGameOver ? const SizedBox.shrink() : Opacity( 
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
                                    
                                    bool isHeldLocally = heldColor == c && heldKilnIdx == kIdx;
                                    bool isHeldByTurnPlayer = false;
                                    if (turnPlayer != null && activeSelection != null && activeSelection![turnPlayer] != null) {
                                        var sel = activeSelection![turnPlayer];
                                        if (sel['color'] == c && sel['kiln_idx'] == kIdx) isHeldByTurnPlayer = true;
                                    }
                                    bool isHeld = isHeldLocally || (isHeldByTurnPlayer && turnPlayer != myName);
                                    bool anyHeldInThisKiln = (heldKilnIdx == kIdx) || (activeSelection?[turnPlayer]?['kiln_idx'] == kIdx);
                                    bool dim = anyHeldInThisKiln && !isHeld;

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() { heldColor = c; heldKilnIdx = kIdx; heldCount = factories![kIdx].where((t) => t == c).length; });
                                        _broadcastHover(heldColor, heldKilnIdx);
                                      },
                                      child: _buildTile(c, size: 18, opacity: dim ? 0.3 : 1.0, scale: isHeld ? 1.2 : 1.0),
                                    );
                                  }).toList())),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          key: centerKey,
                          constraints: const BoxConstraints(minHeight: 64), width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: const Color(0xFFE5E0D8), borderRadius: BorderRadius.circular(12), border: const Border(top: BorderSide(color: Colors.black12, width: 2))), 
                          child: Center(child: center!.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, color: Colors.grey)) : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Wrap(spacing: 4, runSpacing: 4, children: center!.map((c) {
                              bool isHeldLocally = heldColor == c && heldKilnIdx == -1;
                              bool isHeldByTurnPlayer = false;
                              if (turnPlayer != null && activeSelection != null && activeSelection![turnPlayer] != null) {
                                  var sel = activeSelection![turnPlayer];
                                  if (sel['color'] == c && sel['kiln_idx'] == -1) isHeldByTurnPlayer = true;
                              }
                              bool isHeld = isHeldLocally || (isHeldByTurnPlayer && turnPlayer != myName);

                              return GestureDetector(
                                onTap: c == "first_player" ? null : () {
                                  setState(() { heldColor = c; heldKilnIdx = -1; heldCount = center!.where((t) => t == c).length; });
                                  _broadcastHover(heldColor, heldKilnIdx);
                                },
                                child: _buildTile(c, size: 22, scale: isHeld ? 1.2 : 1.0)
                              );
                            }).toList()),
                          )),
                        )
                      ],
                    ),
                  ),
                ))),

                Expanded(flex: 45, child: Container(
                  color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((myBoard['wins'] ?? 0) > 0) ...[
                              const Icon(Icons.emoji_events, size: 14, color: tGold),
                              const SizedBox(width: 2),
                              Text("${myBoard['wins']}  •  ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tGold)),
                            ],
                            Text("SCORE: ${myBoard['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: tTeal)),
                          ]
                        )
                      ]),
                      const SizedBox(height: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.contain, 
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: List.generate(5, (rIdx) {
                                          String? errorMsg = heldColor != null ? _getPlacementError(rIdx, heldColor!) : null;
                                          bool isLegal = heldColor != null && errorMsg == null;
                                          bool isHovered = hoveredRow == rIdx;
                                          
                                          return GestureDetector(
                                            onTap: heldColor != null ? () {
                                              if (isLegal) _commitTurn(rIdx);
                                              else { HapticFeedback.vibrate(); ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: tTerra, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2))); }
                                            } : null,
                                            onPanUpdate: (_) => setState(() => hoveredRow = rIdx),
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(vertical: 2),
                                              color: Colors.transparent,
                                              child: Row(
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

                                                  bool isFullRow = (patternLines[rIdx] as List).where((s) => s == "").isEmpty;
                                                  if (isFullRow) {
                                                    if (_showSlide && slotIdx == rIdx && _scoringRows.contains(rIdx)) { 
                                                      tileW = _buildTile("", size: 24, empty: true);
                                                    } else if (_showShatter && slotIdx < rIdx && _scoringRows.contains(rIdx)) { 
                                                      // TICKET #1 FIX: AnimatedScale makes the tiles physically shrink away instead of just flashing out.
                                                      tileW = AnimatedScale(
                                                        scale: _showShatter ? 0.0 : 1.0,
                                                        duration: const Duration(milliseconds: 400),
                                                        curve: Curves.easeInBack,
                                                        child: AnimatedOpacity(
                                                          opacity: _showShatter ? 0.0 : 1.0, 
                                                          duration: const Duration(milliseconds: 400), 
                                                          child: tileW
                                                        )
                                                      );
                                                    }
                                                  }
                                                  
                                                  Key? slotKey;
                                                  if (slotIdx == rIdx) slotKey = patternRowKeys[rIdx];
                                                  
                                                  return SizedBox(width: 27, height: 27, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [Positioned(key: slotKey, child: tileW)]));
                                                }),
                                              ),
                                            ),
                                          );
                                        }),
                                      )
                                    ]
                                  ),
                                  const SizedBox(width: 24), 
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        children: List.generate(5, (rIdx) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(5, (cIdx) {
                                                String t = (wall.length > rIdx && wall[rIdx].length > cIdx) ? wall[rIdx][cIdx] : "";
                                                Widget slotW = t != "" ? _buildTile(t, size: 24) : _buildTile(wallPattern[rIdx][cIdx], size: 24, isGhost: true);
                                                
                                                Widget floatText = const SizedBox.shrink();
                                                if (_showPop && _scoringRows.contains(rIdx)) {
                                                  String rColor = patternLines[rIdx][0];
                                                  if (wallPattern[rIdx][cIdx] == rColor) {
                                                    int pts = _incomingPayload?['last_scored']?[myName]?[rIdx.toString()] ?? 1;
                                                    floatText = TweenAnimationBuilder<double>(
                                                      tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic,
                                                      builder: (context, val, child) {
                                                        return Transform.translate(offset: Offset(0, -30 * val), child: Opacity(opacity: 1.0 - val, child: Text("+${pts}", style: const TextStyle(color: tGold, fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]))));
                                                      }
                                                    );
                                                  }
                                                }
                                                return SizedBox(width: 27, height: 27, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [Positioned(child: slotW), Positioned(child: floatText)]));
                                              }),
                                            ),
                                          );
                                        }),
                                      )
                                    ]
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
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
                                        tileW = AnimatedScale(
                                          scale: _showShatter ? 0.0 : 1.0,
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeInBack,
                                          child: AnimatedOpacity(
                                            opacity: _showShatter ? 0.0 : 1.0, 
                                            duration: const Duration(milliseconds: 400), 
                                            child: tileW
                                          )
                                        );
                                      }
                                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 27, height: 27, child: Stack(alignment: Alignment.center, children:[Positioned(child: tileW)])), const SizedBox(height: 4), Text(shatterPenalties[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tTerra))]));
                                    }),
                                  ),
                                ),
                              ),
                              _buildBonusTrackers(wall) 
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
            
            if (_isGameOver && !_isReviewingBoard)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: tBg, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, size: 48, color: tGold),
                          const SizedBox(height: 8),
                          const Text("MOSAIC COMPLETE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)),
                          const SizedBox(height: 24),
                          ...finalScores.map((p) {
                            bool isMe = p['name'] == myName;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: isMe ? Colors.white : tSurface, borderRadius: BorderRadius.circular(16), border: isMe ? Border.all(color: tGold, width: 2) : null),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        CircleAvatar(radius: 12, backgroundColor: tTeal, child: Text(p['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), 
                                        const SizedBox(width: 8), 
                                        Text(p['name'].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? tGold : tInk)),
                                        if ((p['wins'] ?? 0) > 0) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.emoji_events, size: 14, color: tGold),
                                          Text("${p['wins']}", style: const TextStyle(color: tGold, fontWeight: FontWeight.bold, fontSize: 12))
                                        ]
                                      ]),
                                      Text("${p['final']} PTS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: isMe ? tGold : tInk)),
                                    ]
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildScoreStat("Base Points", p['base'].toString()),
                                      _buildScoreStat("Row Bonus", "+${p['rows']}"),
                                    ]
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildScoreStat("Col Bonus", "+${p['cols']}"),
                                      _buildScoreStat("Color Bonus", "+${p['colors']}"),
                                    ]
                                  )
                                ]
                              )
                            );
                          }).toList(),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () => setState(() => _isReviewingBoard = true),
                            child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: tTeal, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: tTeal.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]), child: const Center(child: Text("REVIEW BOARDS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
                          )
                        ]
                      )
                    )
                  )
                )
              ),
          ],
        ),
      ),
    );
  }
}