import 'package:flutter/material.dart';
import '../main.dart';
import 'lobby.dart';
import 'local_play.dart';
import 'sandbox.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // App Branding
              const Icon(Icons.grid_view_rounded, size: 80, color: tTeal),
              const SizedBox(height: 24),
              const Text(
                "NOLPAN",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 8, color: tInk),
              ),
              const Text(
                "TABLETOP ENGINE",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.grey),
              ),
              
              const Spacer(),

              // Navigation Buttons
              PhysicsButton(
                text: "PLAY ONLINE",
                color: tTeal,
                shadowColor: const Color(0xFF1E7066),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen())),
              ),
              const SizedBox(height: 16),
              PhysicsButton(
                text: "PASS & PLAY",
                color: tGold,
                shadowColor: const Color(0xFFB59A53),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalPlayScreen())),
              ),
              const SizedBox(height: 16),
              PhysicsButton(
                text: "ANIMATION SANDBOX",
                color: tIce,
                shadowColor: const Color(0xFFB5BBC4),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SandboxScreen())),
              ),
              
              const Spacer(),
              const Text("v16.1 • Live Production", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}