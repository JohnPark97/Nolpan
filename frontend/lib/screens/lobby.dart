import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String roomCode = "WAIT...";
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    // Listen for Go server's response
    _sub = socketService.stream.listen((message) {
      if (message['type'] == 'ROOM_CREATED') {
        setState(() { roomCode = message['payload']['code']; });
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel(); // Prevent memory leaks when leaving screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Gathering Room", style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Text(roomCode, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Color(0xFF2A9D8F), letterSpacing: 8)),
            const SizedBox(height: 64),
            const CircularProgressIndicator(color: Color(0xFFE9C46A)),
          ],
        ),
      ),
    );
  }
}