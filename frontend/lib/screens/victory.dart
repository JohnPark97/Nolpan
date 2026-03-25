import 'package:flutter/material.dart';
import '../main.dart';

class VictoryScreen extends StatelessWidget {
  final String winnerName = "John";
  final int winnerScore = 72;
  final List<Map<String, dynamic>> runnerUps = [{'name': 'Sarah', 'score': 58}];
  final List<Map<String, dynamic>> ledger = [
    {'name': 'John', 'lastScore': 72, 'wins': 3},
    {'name': 'Sarah', 'lastScore': 58, 'wins': 1},
  ];

  VictoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(
          children: [
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
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.topCenter, clipBehavior: Clip.none,
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
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(16),
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
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhysicsButton(text: "Play Again (Keep Lobby)", color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: () {}),
                  const SizedBox(height: 20),
                  GestureDetector(onTap: () {}, child: const Text("Leave Room", style: TextStyle(color: tTerra, fontWeight: FontWeight.bold, fontSize: 14)))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}