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
  Map<String, dynamic>? draftingIntents;
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
      
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() { _showPop = true; });
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 400));
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
    draftingIntents = Map<String, dynamic>.from(payload['drafting_intents'] ?? {});
    turnPlayer = payload['turn_player'] ?? (boards!.isNotEmpty ? boards!.keys.first : "...");
    setState(() {
      heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null;
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
        return "Built in row!";
      }
    }
    if (patternLines.length > rowIdx) {
      for (var t in patternLines[rowIdx]) { if (t != "" && t != color) return "Wrong color!"; }
      int emptySlots = (patternLines[rowIdx] as List).where((s) => s == "").length;
      if (emptySlots == 0) return "Full!";
    }
    return null; 
  }

  void _commitTurn(int targetRow) {
    if (heldColor == null || heldKilnIdx == null) return;
    HapticFeedback.mediumImpact();
    setState(() { heldColor = null; heldKilnIdx = null; heldCount = null; hoveredRow = null; _isWaitingForServer = true; });
    
    if (socketService.currentRoomCode != null) {
      socketService.send('PICK_TILES', {
        'code': socketService.currentRoomCode,
        'player': socketService.playerName,
        'kiln_idx': heldKilnIdx,
        'color': heldColor,
        'target_row': targetRow
      });
    }
  }

  void _sendIntent(String color, int count) {
    socketService.send('DRAFTING_INTENT', {
      'code': socketService.currentRoomCode,
      'name': socketService.playerName,
      'intent': {'color': color, 'count': count}
    });
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
        return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: const Color(0xFFF3E5AB), borderRadius: BorderRadius.circular(4), border: Border.all(color: tGold, width: 2)));
    }
    return Transform.scale(
      scale: scale,
      child: Container(
        width: size, height: size, margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(color: isGhost ? bg.withOpacity(0.15) : bg.withOpacity(opacity), borderRadius: BorderRadius.circular(4)),
        child: Center(child: Icon(icon, size: size * 0.45, color: Colors.white.withOpacity(0.5 * opacity))),
      ),
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
    double fz = isOpp ? 10 : 14;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu, size: isOpp ? 10 : 16, color: Colors.grey), Text(" ${rows}", style: TextStyle(fontSize: fz)),
          const SizedBox(width: 8),
          Icon(Icons.view_column, size: isOpp ? 10 : 16, color: Colors.grey), Text(" ${cols}", style: TextStyle(fontSize: fz)),
          const SizedBox(width: 8),
          Icon(Icons.diamond_outlined, size: isOpp ? 10 : 16, color: Colors.grey), Text(" ${colors}", style: TextStyle(fontSize: fz)),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (factories == null || boards == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    String myName = socketService.playerName ?? "Player";
    bool isMyTurn = turnPlayer == myName && !_isAnimatingScoring && !_isWaitingForServer && !_isGameOver;
    Map<String, dynamic> myBoard = boards![myName] ?? {};
    List patternLines = myBoard['pattern_lines'] ?? [];
    List wall = myBoard['wall'] ?? [];
    List floor = myBoard['floor_line'] ?? [];
    List<String> opponents = boards!.keys.where((k) => k != myName).toList();

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tTeal, letterSpacing: 2))),
            
            Expanded(flex: 22, child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: opponents.map((opp) {
                var board = boards![opp] ?? {};
                var intent = draftingIntents?[opp];
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        CircleAvatar(radius: 10, child: Text(opp[0].toUpperCase())),
                        Text("${board['score'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      const Spacer(),
                      if (intent != null) Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(intent['count'] ?? 0, (i) => _buildTile(intent['color'], size: 10, opacity: 0.5)),
                      ),
                      const Spacer(),
                      _buildBonusTrackers(board['wall'], isOpp: true)
                    ]),
                  ),
                );
              }).toList(),
            )),

            Expanded(flex: 33, child: _isGameOver ? const Center(child: Text("GAME OVER")) : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(factories!.length, (kIdx) {
                  return GestureDetector(
                    onTap: () {
                      if (!isMyTurn || factories![kIdx].isEmpty) return;
                      var color = factories![kIdx][0];
                      setState(() { heldColor = color; heldKilnIdx = kIdx; heldCount = factories![kIdx].length; });
                      _sendIntent(color, heldCount!);
                    },
                    child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: Wrap(children: factories![kIdx].map((c) => _buildTile(c, size: 16)).toList()))),
                  );
                })),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 16),
                  constraints: const BoxConstraints(minHeight: 60), 
                  decoration: BoxDecoration(color: const Color(0xFFE5E0D8), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Wrap(children: center!.map((c) => GestureDetector(
                    onTap: () {
                      if (!isMyTurn || c == "first_player") return;
                      setState(() { heldColor = c; heldKilnIdx = -1; heldCount = center!.where((t) => t == c).length; });
                      _sendIntent(c, heldCount!);
                    },
                    child: _buildTile(c, size: 22)
                  )).toList())),
                )
              ],
            )),

            Expanded(flex: 45, child: Container(
              color: Colors.white, padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("MY WORKSHOP"), Text("SCORE: ${myBoard['score'] ?? 0}")]),
                Expanded(child: FittedBox(child: Column(children: [
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(5, (r) => GestureDetector(
                      onTap: () => _commitTurn(r),
                      child: Row(children: List.generate(r + 1, (c) {
                        bool scoring = _scoringRows.contains(r);
                        return AnimatedOpacity(
                          opacity: scoring && _showShatter ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 400),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            transform: scoring && _showSlide ? Matrix4.translationValues(40, 0, 0) : Matrix4.identity(),
                            child: _buildTile( (patternLines[r].length > c) ? patternLines[r][c] : "", size: 24, empty: (patternLines[r][c] == ""))
                          ),
                        );
                      })),
                    ))),
                    const SizedBox(width: 20),
                    Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) => _buildTile(wall.length > r && wall[r].length > c ? wall[r][c] : "", size: 24, isGhost: true))))),
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(7, (i) => _buildTile(floor.length > i ? floor[i] : "", size: 20, empty: floor.length <= i))),
                ]))),
              ]),
            ))
          ],
        ),
      ),
    );
  }
}