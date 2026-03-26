import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';
import 'lobby.dart';

class VictoryScreen extends StatefulWidget {
  final Map<String, dynamic> finalState;
  const VictoryScreen({super.key, required this.finalState});

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen> {
  late StreamSubscription _sub;
  List<Map<String, dynamic>> rankings = [];

  @override
  void initState() {
    super.initState();
    _parseStandings();
    
    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'RETURN_TO_LOBBY') {
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LobbyScreen()), (route) => false);
        }
      }
    });
  }

  void _parseStandings() {
    Map<String, dynamic> boards = widget.finalState['boards'] ?? {};
    boards.forEach((name, data) {
      rankings.add({
        'name': name,
        'score': data['score'] ?? 0,
      });
    });
    rankings.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.emoji_events, size: 64, color: tGold),
                    SizedBox(height: 12),
                    Text("MOSAIC COMPLETE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.grey)),
                    Text("Final Standings", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: tInk)),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              Expanded(
                child: ListView.builder(
                  itemCount: rankings.length,
                  itemBuilder: (context, index) {
                    bool isWinner = index == 0;
                    var p = rankings[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isWinner ? Colors.white : tSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: isWinner ? Border.all(color: tGold, width: 2) : null,
                        boxShadow: isWinner ? [BoxShadow(color: tGold.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))] : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isWinner ? tGold : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text("#${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isWinner ? tGold : tInk)),
                              ],
                            ),
                          ),
                          Text("${p['score']} PTS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isWinner ? tGold : tInk)),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              PhysicsButton(
                text: "PLAY AGAIN WITH SAME LOBBY",
                color: tTeal,
                shadowColor: const Color(0xFF1A695F),
                onTap: () {
                  if (socketService.currentRoomCode != null) {
                    socketService.send('PLAY_AGAIN', {'code': socketService.currentRoomCode});
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}