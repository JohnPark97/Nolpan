import 'package:flutter/material.dart';
import '../main.dart';
import 'gateway.dart';

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
            children: [
              Expanded(child: Center(child: Text("NOLPAN", style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: tInk, letterSpacing: 4)))),
              PhysicsButton(
                text: "Play Online", color: tTeal, shadowColor: const Color(0xFF1A695F),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GatewayScreen())),
              ),
              const SizedBox(height: 16),
              PhysicsButton(
                text: "Pass & Play (Offline)", color: tTerra, shadowColor: const Color(0xFFA84128),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Offline mode coming soon!"))),
              ),
              const SizedBox(height: 32),
              Text("v1.0 - Purely for friends. No strangers. Always free.", style: TextStyle(fontSize: 10, color: tInk.withOpacity(0.5), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}