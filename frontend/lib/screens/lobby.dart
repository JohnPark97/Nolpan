import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';
import 'game.dart';

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
    
    // THE FIX: Read from memory cache immediately so UI doesn't hang!
    if (socketService.lastRoomUpdate != null) {
      roomCode = socketService.lastRoomUpdate!['payload']['code'];
      players = List<String>.from(socketService.lastRoomUpdate!['payload']['players']);
    }

    _sub = socketService.stream.listen((message) {
      if (message['type'] == 'ROOM_UPDATE') {
        setState(() {
          roomCode = message['payload']['code'];
          players = List<String>.from(message['payload']['players']);
        });
      }
      if (message['type'] == 'GAME_STARTED') {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => GameScreen(initialState: message['payload'])
        ));
      }
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(roomCode, style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Color(0xFF2A9D8F), letterSpacing: 8)),
            const Text("SHARE THIS CODE", style: TextStyle(color: Colors.grey, letterSpacing: 2, fontSize: 12)),
            const Divider(height: 60, indent: 40, endIndent: 40),
            Expanded(
              child: players.isEmpty 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2A9D8F)))
                : ListView.builder(
                    itemCount: players.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemBuilder: (context, index) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == 0 ? const Color(0xFF2A9D8F) : Colors.grey[300],
                          child: Icon(Icons.person, color: index == 0 ? Colors.white : Colors.grey[600]),
                        ),
                        title: Text(players[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: index == 0 ? const Chip(label: Text("HOST", style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Color(0xFF2A9D8F)) : null,
                      ),
                    ),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: players.length >= 2 ? () {
                  socketService.send('START_GAME', {'code': roomCode});
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A9D8F),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: Colors.grey[300]
                ),
                child: Text(
                  players.length >= 2 ? "START GAME" : "WAITING FOR PLAYERS...",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}