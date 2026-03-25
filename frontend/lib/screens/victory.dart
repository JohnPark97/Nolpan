import 'package:flutter/material.dart';

// DESIGN TOKENS (Strict adherence to Spec 6)
const Color tBg = Color(0xFFF9F7F3);
const Color tSurface = Color(0xFFFFFFFF);
const Color tTeal = Color(0xFF2A9D8F);
const Color tGold = Color(0xFFE9C46A);
const Color tInk = Color(0xFF2B2D42);
const Color tTerra = Color(0xFFE76F51);

class VictoryScreen extends StatelessWidget {
  // Mock Data (To be wired to Go backend in Phase 4)
  final String winnerName = "John";
  final int winnerScore = 72;
  final List<Map<String, dynamic>> runnerUps = [{'name': 'Sarah', 'score': 58}];
  final List<Map<String, dynamic>> ledger = [
    {'name': 'John', 'lastScore': 72, 'wins': 3},
    {'name': 'Sarah', 'lastScore': 58, 'wins': 1},
  ];

  const VictoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      // STRICT RULE 1: NO SCROLLING (100vh wrapper)
      body: SafeArea(
        child: Column(
          children: [
            // ZONE 1: CELEBRATION HEADER (flex: 1)
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("MOSAIC COMPLETE!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: tGold, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text("Game Over", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: tInk.withOpacity(0.6), letterSpacing: 4)),
                ],
              ),
            ),

            // ZONE 2: WINNER PODIUM (flex: 3)
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Winner Hero Avatar
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tGold, width: 4), color: tTeal),
                        child: Center(child: Text(winnerName[0].toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))),
                      ),
                      Positioned(top: -15, child: Icon(Icons.workspace_premium, color: tGold, size: 36, shadows: [Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(winnerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: tInk)),
                  Text("$winnerScore Points", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: tInk, letterSpacing: -1)),
                  
                  const SizedBox(height: 32),
                  // Runner-ups
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: runnerUps.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          CircleAvatar(radius: 24, backgroundColor: Colors.grey[400], child: Text(r['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 8),
                          Text(r['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text("${r['score']} pts", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    )).toList(),
                  )
                ],
              ),
            ),

            // ZONE 3: SESSION LEDGER (flex: 2)
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: tSurface.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("SESSION LEADERBOARD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: tInk.withOpacity(0.5))),
                      const SizedBox(height: 12),
                      ...ledger.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tInk)),
                            Text("Last: ${l['lastScore']}", style: TextStyle(fontSize: 12, color: tInk.withOpacity(0.6))),
                            Text("👑 ${l['wins']} Wins", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tGold)),
                          ],
                        ),
                      ))
                    ],
                  ),
                ),
              ),
            ),

            // ZONE 4: ACTION DOCK (flex: none)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhysicsButton(
                    text: "Play Again (Keep Lobby)",
                    color: tTeal,
                    shadowColor: const Color(0xFF1A695F),
                    onTap: () {
                      // TODO: Send RESET_GAME to Go Server
                    },
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      // TODO: Disconnect and pop to Gateway
                    },
                    child: const Text("Leave Room", style: TextStyle(color: tTerra, fontWeight: FontWeight.bold, fontSize: 14)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// STRICT RULE 3: THE "THOUGHTFUL SNAP" PHYSICS BUTTON
class PhysicsButton extends StatefulWidget {
  final String text;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;

  const PhysicsButton({super.key, required this.text, required this.color, required this.shadowColor, required this.onTap});

  @override
  State<PhysicsButton> createState() => _PhysicsButtonState();
}

class _PhysicsButtonState extends State<PhysicsButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100), // Quick snap
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(top: _isPressed ? 4 : 0, bottom: _isPressed ? 0 : 4),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(12),
          border: Border(bottom: BorderSide(color: _isPressed ? Colors.transparent : widget.shadowColor, width: 4)),
        ),
        child: Center(
          child: Text(widget.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
        ),
      ),
    );
  }
}