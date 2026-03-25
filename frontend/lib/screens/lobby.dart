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
  bool _isStarting = false;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
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
        _sub.cancel();
        if (mounted) {
          setState(() { _isStarting = false; });
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(initialState: message['payload'])));
        }
      }
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  void _startGame() {
    setState(() { _isStarting = true; });
    socketService.send('START_GAME', {'code': roomCode});
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isStarting) setState(() { _isStarting = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "";

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Lobby", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: tInk)),
                  PhysicsButton(
                    text: "", color: tSurface, shadowColor: Colors.grey[300]!, isFullWidth: false,
                    onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!"))); },
                    customChild: Row(mainAxisSize: MainAxisSize.min, children: [Text("Code: $roomCode", style: const TextStyle(color: tInk, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(width: 8), const Icon(Icons.ios_share, color: tInk, size: 16)]),
                  )
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: players.isEmpty 
                  ? const CircularProgressIndicator(color: tTeal)
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 32, runSpacing: 32, alignment: WrapAlignment.center,
                        children: players.map((p) {
                          bool isMe = p == myName;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: tSurface, border: Border.all(color: isMe ? tTeal : Colors.transparent, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                                child: Center(child: Text(p[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: tInk))),
                              ),
                              const SizedBox(height: 8),
                              Text(p + (isMe ? " (You)" : ""), style: TextStyle(fontWeight: FontWeight.w500, color: isMe ? tTeal : tInk)),
                            ],
                          );
                        }).toList(),
                      ),
                  ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: tBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -10))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: ['Prestige', 'Mosaic', 'Treason'].map((game) {
                      bool isSelected = _selectedGame == game;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGame = game),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
                            margin: EdgeInsets.only(right: game == 'Treason' ? 0 : 8, top: isSelected ? 0 : 4, bottom: isSelected ? 4 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: tSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? tTeal : Colors.transparent, width: 2), boxShadow: isSelected ? [BoxShadow(color: tTeal.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : []),
                            child: Center(child: Text(game, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tInk.withOpacity(isSelected ? 1.0 : 0.5)))),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  PhysicsButton(
                    text: _isStarting ? "Gathering players..." : "Start $_selectedGame",
                    color: players.length >= 2 ? tTeal : Colors.grey[400]!, shadowColor: players.length >= 2 ? const Color(0xFF1A695F) : Colors.grey[500]!,
                    onTap: (players.length >= 2 && !_isStarting) ? _startGame : () {},
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