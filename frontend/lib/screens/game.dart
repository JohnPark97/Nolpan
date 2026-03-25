import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';

class GameScreen extends StatefulWidget {
  final Map<String, dynamic> initialState;
  const GameScreen({super.key, required this.initialState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<List<String>> factories;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _updateState(widget.initialState);

    _sub = socketService.stream.listen((message) {
      if (message['type'] == 'GAME_STARTED' || message['type'] == 'GAME_UPDATE') {
        if (mounted) {
          setState(() { _updateState(message['payload']); });
        }
      }
    });
  }
  
  void _updateState(Map<String, dynamic> payload) {
    factories = (payload['factories'] as List)
        .map((f) => List<String>.from(f))
        .toList();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Color _getTileColor(String name) {
    switch (name) {
      case 'blue': return Colors.blue[800]!;
      case 'yellow': return const Color(0xFFFFD54F);
      case 'red': return Colors.red[700]!;
      case 'black': return Colors.grey[900]!;
      case 'white': return Colors.white;
      default: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      appBar: AppBar(
        title: const Text("DRAFTING PHASE", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF2B2D42),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          const Text("FACTORIES", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 4)),
          const SizedBox(height: 10),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 30, mainAxisSpacing: 30
              ),
              itemCount: factories.length,
              itemBuilder: (context, i) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE9C46A), width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 5))]
                ),
                child: Center(
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: factories[i].map((tile) => Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _getTileColor(tile),
                        borderRadius: BorderRadius.circular(6),
                        border: tile == 'white' ? Border.all(color: Colors.grey[300]!) : null,
                        // THE FIX: Raw Hex instead of Colors.black24
                        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 2))]
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 10)]
            ),
            child: const Text(
              "Waiting for your turn...", 
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2A9D8F))
            ),
          )
        ],
      ),
    );
  }
}