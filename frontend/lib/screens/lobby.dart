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
  String _selectedGame = "Mosaic";

  @override
  void initState() {
    super.initState();
    socketService.stream.listen((msg) {
      if (msg['type'] == 'ROOM_UPDATE') { setState(() { roomCode = msg['payload']['code']; players = List<String>.from(msg['payload']['players']); }); }
      if (msg['type'] == 'GAME_STARTED') { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(initialState: msg['payload']))); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Lobby", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            PhysicsButton(text: "Code: $roomCode", color: tSurface, shadowColor: Colors.grey[300]!, isFullWidth: false, onTap: () {})
          ])),
          Expanded(child: Center(child: Wrap(spacing: 32, runSpacing: 32, children: players.map((p) => Column(children: [CircleAvatar(radius: 32, backgroundColor: tTeal, child: Text(p[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24))), const SizedBox(height: 8), Text(p)])).toList()))),
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: tBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]), child: Column(children: [
            Row(children: ['Prestige', 'Mosaic', 'Treason'].map((g) => Expanded(child: GestureDetector(onTap: () => setState(() => _selectedGame = g), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: tSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _selectedGame == g ? tTeal : Colors.transparent, width: 2)), child: Center(child: Text(g, style: TextStyle(fontWeight: FontWeight.bold, color: _selectedGame == g ? tTeal : tInk.withOpacity(0.5)))))))).toList()),
            const SizedBox(height: 24),
            PhysicsButton(text: "Start $_selectedGame", color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: () => socketService.send('START_GAME', {'code': roomCode}))
          ]))
        ]),
      ),
    );
  }
}