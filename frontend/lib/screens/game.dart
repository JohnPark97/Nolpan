import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../main.dart';
import 'victory.dart';

// DESIGN TOKENS
const Color tTeal = Color(0xFF2A9D8F);
const Color tTerra = Color(0xFFE76F51);
const Color tGold = Color(0xFFE9C46A);
const Color tInk = Color(0xFF2B2D42);
const Color tIce = Color(0xFFE0E5EC);
const Color tBg = Color(0xFFF9F7F3);

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

  // ENGINEERING FIX: GLOBAL KEY REGISTRY FOR FLIP ANIMATIONS
  // This allows us to find the exact X/Y screen coordinates of any slot on the board.
  final List<List<GlobalKey>> patternKeys = List.generate(5, (r) => List.generate(r + 1, (c) => GlobalKey()));
  final List<List<GlobalKey>> wallKeys = List.generate(5, (r) => List.generate(5, (c) => GlobalKey()));
  final List<GlobalKey> floorKeys = List.generate(7, (i) => GlobalKey());
  final GlobalKey factoryPoolKey = GlobalKey();

  // Animation State Triggers
  bool _clearPatternTrigger = false;
  List<int> _pulseWallTrigger = []; // [row, col]

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

  // --------------------------------------------------------------------------------
  // CORE PHYSICS ENGINE: THE FLIGHT CONTROLLER
  // --------------------------------------------------------------------------------
  void _flyTile({
    required GlobalKey startKey,
    required GlobalKey endKey,
    required String tileColor,
    Duration delay = Duration.zero,
    Curve curve = Curves.fastOutSlowIn,
    bool isGravityDrop = false,
    VoidCallback? onComplete,
  }) {
    // 1. Get exact X/Y coordinates of the start and end widgets
    final RenderBox? startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = endKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;

    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);

    // 2. Create the Z-Index Overlay
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: curve,
        builder: (context, double value, child) {
          // Math: Lerp position between Start X/Y and End X/Y
          double currentX = lerpDouble(startPos.dx, endPos.dx, value)!;
          double currentY = lerpDouble(startPos.dy, endPos.dy, value)!;
          
          // Math: The Lift (Scale up to 1.15 in the middle of flight, then back down)
          double scale = isGravityDrop ? 1.0 : (value < 0.5 ? 1.0 + (value * 0.3) : 1.15 - ((value - 0.5) * 0.3));

          return Positioned(
            left: currentX,
            top: currentY,
            child: Transform.scale(
              scale: scale,
              child: _buildPhysicsTile(tileColor),
            ),
          );
        },
        onEnd: () {
          entry.remove(); // Kill overlay when flight finishes
          if (onComplete != null) onComplete();
        },
      ),
    );

    // 3. Launch with specified stagger delay
    Future.delayed(delay, () {
      if (mounted) Overlay.of(context).insert(entry);
    });
  }

  // --------------------------------------------------------------------------------
  // CHOREOGRAPHY SEQUENCES
  // --------------------------------------------------------------------------------
  void _triggerScoringChoreography() {
    // INTERACTION 1: THE SNAP TO WALL (Flight + Lift + Pulse + Clear)
    _flyTile(
      startKey: patternKeys[4][4], // Start: Bottom right of pattern lines
      endKey: wallKeys[4][0],      // End: Bottom left of Wall
      tileColor: 'yellow',
      curve: const Cubic(0.2, 0.8, 0.2, 1), // The "Thoughtful Snap" Curve
      onComplete: () {
        // Trigger The Pulse & The Clear
        setState(() {
          _pulseWallTrigger = [4, 0];
          _clearPatternTrigger = true;
        });
        // Reset state after animation finishes
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() { _pulseWallTrigger = []; _clearPatternTrigger = false; });
        });
      }
    );

    // INTERACTION 2: THE STAGGERED DROP (Gravity + Delays)
    List<int> staggers = [0, 75, 150];
    for (int i = 0; i < 3; i++) {
      _flyTile(
        startKey: factoryPoolKey, // Start: Center of the screen
        endKey: floorKeys[i],     // End: The Shatter Line slots
        tileColor: 'red',
        delay: Duration(milliseconds: staggers[i]), // Staggered delay
        isGravityDrop: true,
        curve: Curves.bounceOut, // Gravity Physics
      );
    }
  }

  // --------------------------------------------------------------------------------
  // UI BUILDERS
  // --------------------------------------------------------------------------------
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
      key: factoryPoolKey, // Track center screen for Drop origin
      padding: const EdgeInsets.all(16),
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
                // PATTERN STAIRCASE (With Global Keys attached)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (r) {
                    List<String> rowTiles = List<String>.from(patternLines[r]);
                    return Row(children: List.generate(r + 1, (c) {
                      bool isAnimatingClear = _clearPatternTrigger && r == 4 && c < 4;
                      
                      // Step 5 of Interaction 1: The Clear (Fade out and drop duplicate tiles)
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isAnimatingClear ? 0.0 : 1.0,
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
                // THE WALL (With Global Keys and Pulse Animation)
                Column(
                  children: List.generate(5, (r) {
                    List<String> rowTiles = List<String>.from(wall[r]);
                    return Row(
                      children: List.generate(5, (c) {
                        bool isPulsing = _pulseWallTrigger.isNotEmpty && _pulseWallTrigger[0] == r && _pulseWallTrigger[1] == c;
                        String tile = rowTiles[c];
                        
                        // Step 4 of Interaction 1: The Pulse
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.all(isPulsing ? 2 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: isPulsing ? Colors.white : Colors.transparent,
                            boxShadow: isPulsing ? [const BoxShadow(color: tGold, blurRadius: 8, spreadRadius: 2)] : [],
                          ),
                          child: tile != "" ? _buildPhysicsTile(tile, key: wallKeys[r][c]) : _buildPhysicsTile(wallPattern[r][c], isGhost: true, key: wallKeys[r][c]),
                        );
                      }),
                    );
                  }),
                )
              ],
            ),
          ),
          // THE SHATTER LINE (With Global Keys attached)
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
          // ACTION BAR (Triggers the Demo Sequence)
          GestureDetector(
            onTap: _triggerScoringChoreography,
            child: Container(
              height: 56, width: double.infinity,
              decoration: BoxDecoration(color: tTeal, borderRadius: BorderRadius.circular(12), border: const Border(bottom: BorderSide(color: Color(0xFF1A695F), width: 4))),
              child: const Center(child: Text("SET MOSAIC (TEST CHOREOGRAPHY)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1))),
            ),
          )
        ],
      ),
    );
  }
}