import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';
import 'lobby.dart';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});
  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() { super.initState(); _codeCtrl.addListener(() => setState(() {})); }

  void _handleAction() {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() { _isConnecting = true; });
    socketService.playerName = _nameCtrl.text.trim();
    socketService.connect('wss://nolpan.onrender.com/ws');
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_codeCtrl.text.isEmpty) { socketService.send('CREATE_ROOM', {'name': _nameCtrl.text}); }
      else { socketService.send('JOIN_ROOM', {'name': _nameCtrl.text, 'code': _codeCtrl.text.toUpperCase()}); }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isCreate = _codeCtrl.text.isEmpty;
    return Scaffold(
      backgroundColor: tBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: tInk), onPressed: () => Navigator.pop(context)),
            Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Who's playing?", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: tInk)),
              const SizedBox(height: 24),
              TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: "What should we call you?", filled: true, fillColor: tSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: _codeCtrl, maxLength: 4, decoration: InputDecoration(hintText: "4-letter code (leave blank to create)", counterText: "", filled: true, fillColor: tSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ])))),
            Padding(padding: const EdgeInsets.all(24), child: PhysicsButton(text: isCreate ? "Create New Room" : "Join Room", color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: _handleAction))
          ],
        ),
      ),
    );
  }
}