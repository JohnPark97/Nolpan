import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED FOR CLIPBOARD
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
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    if (socketService.currentRoomCode != null) { roomCode = socketService.currentRoomCode!; }
    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'ROOM_UPDATE') { 
        setState(() { 
          roomCode = msg['payload']['code']; 
          players = List<String>.from(msg['payload']['players']); 
        }); 
      }
      if (msg['type'] == 'GAME_STARTED') { 
        _sub.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(initialState: msg['payload']))); 
      }
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  // --- THE LOGIC FIX ---
  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: roomCode)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Code $roomCode copied to clipboard!", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: tTeal,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          )
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String myName = socketService.playerName ?? "";
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Lobby", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: tInk)),
            PhysicsButton(
              text: "", color: tSurface, shadowColor: Colors.grey[300]!, isFullWidth: false,
              onTap: _copyRoomCode, // Actual function call
              customChild: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(roomCode, style: const TextStyle(color: tInk, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                  const SizedBox(width: 12),
                  const Icon(Icons.ios_share, color: tInk, size: 18),
                ],
              ),
            )
          ])),
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
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, color: tSurface, 
                                border: Border.all(color: isMe ? tTeal : Colors.transparent, width: 4), 
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                              ),
                              child: Center(child: Text(p[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: tInk))),
                            ),
                            const SizedBox(height: 12),
                            Text(p + (isMe ? " (You)" : ""), style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? tTeal : tInk, fontSize: 16)),
                          ],
                        );
                      }).toList(),
                    ),
                ),
            ),
          ),
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: tBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))]), child: Column(children: [
            Row(children: ['Prestige', 'Mosaic', 'Treason'].map((g) => Expanded(child: GestureDetector(onTap: () => setState(() => _selectedGame = g), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: tSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _selectedGame == g ? tTeal : Colors.transparent, width: 2)), child: Center(child: Text(g, style: TextStyle(fontWeight: FontWeight.bold, color: _selectedGame == g ? tTeal : tInk.withOpacity(0.5)))))))).toList()),
            const SizedBox(height: 24),
            PhysicsButton(
              text: "Start $_selectedGame", 
              color: players.length >= 2 ? tTeal : Colors.grey[400]!, 
              shadowColor: players.length >= 2 ? const Color(0xFF1A695F) : Colors.grey[500]!, 
              onTap: () {
                if (players.length >= 2) {
                  socketService.send('START_GAME', {'code': roomCode});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wait for more players!")));
                }
              }
            )
          ]))
        ]),
      ),
    );
  }
}