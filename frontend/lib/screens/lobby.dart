import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String roomCode = "...";
  List<String> players = [];
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = socketService.stream.listen((message) {
      if (message['type'] == 'ROOM_UPDATE') {
        setState(() {
          roomCode = message['payload']['code'];
          players = List<String>.from(message['payload']['players']);
        });
      }
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(roomCode, style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Color(0xFF2A9D8F), letterSpacing: 8)),
            const Text("SHARE THIS CODE", style: TextStyle(color: Colors.grey, letterSpacing: 2)),
            const Divider(height: 60, indent: 40, endIndent: 40),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF2A9D8F), child: Icon(Icons.person, color: Colors.white)),
                  title: Text(players[index], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  trailing: index == 0 ? const Chip(label: Text("HOST")) : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: players.length >= 2 ? () {} : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9C46A), minimumSize: const Size(double.infinity, 60)),
                child: Text(players.length >= 2 ? "START GAME" : "WAITING FOR PLAYERS..."),
              ),
            )
          ],
        ),
      ),
    );
  }
}