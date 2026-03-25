import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<List<String>> factories;
  late List<String> center;
  late Map<String, dynamic> boards;
  late StreamSubscription _sub;

  final List<List<GlobalKey>> patternKeys = List.generate(5, (r) => List.generate(r + 1, (c) => GlobalKey()));
  final List<List<GlobalKey>> wallKeys = List.generate(5, (r) => List.generate(5, (c) => GlobalKey()));
  final List<GlobalKey> floorKeys = List.generate(7, (i) => GlobalKey());
  final GlobalKey factoryPoolKey = GlobalKey();

  bool _clearPatternTrigger = false;
  List<int> _pulseWallTrigger = []; 

  @override
  void initState() {
    super.initState();
    _updateState(widget.initialState);
    _sub = socketService.stream.listen((message) {
      if (message['type'] == 'GAME_STARTED' || message['type'] == 'GAME_UPDATE') {
        if (mounted) setState(() { _updateState(message['payload']); });
      }
    });
  }

  void _updateState(Map<String, dynamic> payload) {
    factories = (payload['factories'] as List).map((f) => List<String>.from(f)).toList();
    center = List<String>.from(payload['center'] ?? []);
    boards = payload['boards'] ?? {};
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  void _flyTile({required GlobalKey startKey, required GlobalKey endKey, required String tileColor, Duration delay = Duration.zero, Curve curve = Curves.fastOutSlowIn, bool isGravityDrop = false, VoidCallback? onComplete}) {
    final RenderBox? startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = endKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;
    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 400), curve: curve,
        builder: (context, double value, child) {
          double currentX = lerpDouble(startPos.dx, endPos.dx, value)!;
          double currentY = lerpDouble(startPos.dy, endPos.dy, value)!;
          double scale = isGravityDrop ? 1.0 : (value < 0.5 ? 1.0 + (value * 0.3) : 1.15 - ((value - 0.5) * 0.3));
          return Positioned(left: currentX, top: currentY, child: Transform.scale(scale: scale, child: _buildPhysicsTile(tileColor)));
        },
        onEnd: () { entry.remove(); if (onComplete != null) onComplete(); },
      ),
    );
    Future.delayed(delay, () { if (mounted) Overlay.of(context).insert(entry); });
  }

  void _triggerScoringChoreography() {
    _flyTile(
      startKey: patternKeys[4][4], endKey: wallKeys[4][0], tileColor: 'yellow', curve: const Cubic(0.2, 0.8, 0.2, 1),
      onComplete: () {
        setState(() { _pulseWallTrigger = [4, 0]; _clearPatternTrigger = true; });
        Future.delayed(const Duration(milliseconds: 300), () { if (mounted) setState(() { _pulseWallTrigger = []; _clearPatternTrigger = false; }); });
      }
    );
    List<int> staggers = [0, 75, 150];
    for (int i = 0; i < 3; i++) {
      _flyTile(startKey: factoryPoolKey, endKey: floorKeys[i], tileColor: 'red', delay: Duration(milliseconds: staggers[i]), isGravityDrop: true, curve: Curves.bounceOut);
    }
  }

  Widget _buildPhysicsTile(String colorName, {bool empty = false, bool isGhost = false, GlobalKey? key}) {
    Color bg; IconData? icon; Color iconColor = Colors.white; Color shadow = Colors.transparent;
    switch (colorName) {
      case 'blue': bg = tTeal; icon = Icons.star_rounded; shadow = const Color(0xFF1A695F); break;
      case 'red': bg = tTerra; icon = Icons.menu; shadow = const Color(0xFFA84128); break;
      case 'yellow': bg = tGold; icon = Icons.circle; shadow = const Color(0xFFC9A24A); break;
      case 'black': bg = tInk; icon = Icons.close; shadow = const Color(0xFF11121A); break;
      case 'white': bg = tIce; icon = Icons.check_box_outline_blank; iconColor = Colors.grey[400]!; shadow = Colors.grey[300]!; break;
      default: bg = Colors.transparent;
    }

    if (empty) return Container(key: key, width: 24, height: 24, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)));
    if (isGhost) return Container(key: key, width: 24, height: 24, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: bg.withOpacity(0.2), borderRadius: BorderRadius.circular(4)));

    return Container(
      key: key, width: 24, height: 24, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border(bottom: BorderSide(color: shadow, width: 3))),
      child: Center(child: Icon(icon, color: iconColor.withOpacity(0.5), size: 14)),
    );
  }

  Widget _buildOpponentZone(String myName) {
    List<String> opponents = boards.keys.where((k) => k != myName).toList();
    return Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("OPPONENTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(), itemCount: opponents.length,
              itemBuilder: (context, i) {
                var oppBoard = boards[opponents[i]];
                List wall = oppBoard['wall'] ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 16, backgroundColor: tTeal, child: Text(opponents[i][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(opponents[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      Column(children: List.generate(5, (r) => Row(children: List.generate(5, (c) {
                        String tile = wall.length > r ? wall[r][c] : "";
                        return Container(margin: const EdgeInsets.all(1), width: 6, height: 6, decoration: BoxDecoration(color: tile == "" ? Colors.grey[200] : tTeal, borderRadius: BorderRadius.circular(1)));
                      })))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketZone() {
    return Container(
      key: factoryPoolKey, padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.center, spacing: 16, runSpacing: 16,
              children: factories.map((f) => Container(
                width: 64, height: 64, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Center(child: Wrap(spacing: 2, runSpacing: 2, alignment: WrapAlignment.center, children: f.map((t) => _buildPhysicsTile(t)).toList())),
              )).toList(),
            ),
          ),
          Container(
            height: 40, width: double.infinity, decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
            child: Center(child: center.isEmpty ? const Text("CENTER POOL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)) : Wrap(children: center.map((t) => _buildPhysicsTile(t)).toList())),
          )
        ],
      ),
    );
  }

  Widget _buildPlayerZone(String myName) {
    Map<String, dynamic> board = boards[myName] ?? {};
    List patternLines = board['pattern_lines'] ?? List.generate(5, (i) => List.filled(i + 1, ""));
    List wall = board['wall'] ?? List.generate(5, (_) => List.filled(5, ""));
    List floor = board['floor_line'] ?? [];
    List<String> shatterPenalties = ['-1', '-1', '-2', '-2', '-2', '-3', '-3'];

    return Container(
      color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("MY WORKSHOP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey[400])),
              Text("SCORE: ${board['score'] ?? 0}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tTeal)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (r) {
                    List<String> rowTiles = List<String>.from(patternLines[r]);
                    return Row(children: List.generate(r + 1, (c) {
                      bool isAnimatingClear = _clearPatternTrigger && r == 4 && c < 4;
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200), opacity: isAnimatingClear ? 0.0 : 1.0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: isAnimatingClear ? Matrix4.translationValues(0, 10, 0) : Matrix4.identity(),
                          child: _buildPhysicsTile(rowTiles[c], empty: rowTiles[c] == "", key: patternKeys[r][c]),
                        ),
                      );
                    }));
                  }),
                ),
                const SizedBox(width: 24),
                Column(
                  children: List.generate(5, (r) {
                    List<String> rowTiles = List<String>.from(wall[r]);
                    return Row(
                      children: List.generate(5, (c) {
                        bool isPulsing = _pulseWallTrigger.isNotEmpty && _pulseWallTrigger[0] == r && _pulseWallTrigger[1] == c;
                        String tile = rowTiles[c];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150), padding: EdgeInsets.all(isPulsing ? 2 : 0),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: isPulsing ? Colors.white : Colors.transparent, boxShadow: isPulsing ? [const BoxShadow(color: tGold, blurRadius: 8, spreadRadius: 2)] : []),
                          child: tile != "" ? _buildPhysicsTile(tile, key: wallKeys[r][c]) : _buildPhysicsTile(wallPattern[r][c], isGhost: true, key: wallKeys[r][c]),
                        );
                      }),
                    );
                  }),
                )
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) {
              String t = i < floor.length ? floor[i] : "";
              return Column(
                children: [
                  _buildPhysicsTile(t, empty: t == "", key: floorKeys[i]),
                  const SizedBox(height: 2),
                  Text(shatterPenalties[i], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: tTerra)),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PhysicsButton(
                  text: "TEST CHOREOGRAPHY", color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: _triggerScoringChoreography,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PhysicsButton(
                  text: "TEST WIN", color: tGold, shadowColor: const Color(0xFFC9A24A),
                  onTap: () => Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (c, a1, a2) => VictoryScreen(), // THE FIX: Removed 'const'
                    transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim), child: child)),
                    transitionDuration: const Duration(milliseconds: 300),
                  )),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // THE FIX: ADDED MISSING BUILD METHOD!
  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "Player";
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 3, child: _buildOpponentZone(myName)),
            Expanded(flex: 3, child: _buildMarketZone()),
            Expanded(flex: 4, child: _buildPlayerZone(myName)),
          ],
        ),
      ),
    );
  }
}