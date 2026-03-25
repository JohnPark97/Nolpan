import 'package:flutter/material.dart';
import '../main.dart';
import 'lobby.dart';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});
  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final TextEditingController _nameController = TextEditingController();

  void _createRoom() {
    if (_nameController.text.trim().isEmpty) return;
    
    // Connect to Render
    socketService.connect('wss://nolpan.onrender.com/ws');
    
    // Ask Go Server to make a code
    socketService.send('CREATE_ROOM', {'name': _nameController.text.trim()});
    
    // Jump to Lobby screen
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("NOLPAN", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2A9D8F), letterSpacing: 2)),
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: "Enter your name",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A9D8F),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Create Room", style: TextStyle(fontSize: 20, color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }
}