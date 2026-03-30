import 'package:flutter/material.dart';
import '../main.dart';
import 'lobby.dart';
import 'local_play.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Widget _buildLogoTile(Color color, IconData icon, double yOffset) {
    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 6), blurRadius: 8)],
          border: const Border(bottom: BorderSide(color: Colors.black12, width: 4))
        ),
        child: Center(child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 32)),
      ),
    );
  }

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
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogoTile(tTeal, Icons.star, -4.0),
                  const SizedBox(width: 12),
                  _buildLogoTile(const Color(0xFF8E44AD), Icons.diamond, 4.0),
                  const SizedBox(width: 12),
                  _buildLogoTile(tGold, Icons.circle, -2.0),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                "NOLPAN",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 10, color: tInk),
              ),
              const Text(
                "MOSAIC DRAFT",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 6, color: tTeal),
              ),
              
              const Spacer(),

              PhysicsButton(
                text: "PLAY ONLINE",
                color: tTeal,
                shadowColor: const Color(0xFF1E7066),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen())),
              ),
              const SizedBox(height: 16),
              PhysicsButton(
                text: "OFFLINE MODE",
                color: tGold,
                shadowColor: const Color(0xFFB59A53),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalPlayScreen())),
              ),
              
              const Spacer(),
              const Text("v16.3 • Offline Mode Activated", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}