import 'package:flutter/material.dart';
import '../main.dart';

class VictoryScreen extends StatelessWidget {
  final String winnerName = "John";
  final int winnerScore = 72;

  // THE FIX: Constructor is not const to allow for dynamic mock data
  VictoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(children: [
          Expanded(flex: 1, child: Center(child: Text("MOSAIC COMPLETE!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: tGold)))),
          Expanded(flex: 3, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 96, height: 96, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tGold, width: 4), color: tTeal), child: Center(child: Text(winnerName[0], style: const TextStyle(fontSize: 40, color: Colors.white)))),
            const SizedBox(height: 16),
            Text(winnerName, style: const TextStyle(fontSize: 20)),
            Text("$winnerScore Points", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900))
          ])),
          Padding(padding: const EdgeInsets.all(24), child: PhysicsButton(text: "Play Again", color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: () => Navigator.pop(context)))
        ]),
      ),
    );
  }
}