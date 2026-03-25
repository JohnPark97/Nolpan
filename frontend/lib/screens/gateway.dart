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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isConnecting = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  void _handleAction() {
    if (_nameController.text.trim().isEmpty) return;
    bool isCreate = _codeController.text.trim().isEmpty;
    if (!isCreate && _codeController.text.trim().length != 4) return;

    setState(() { _isConnecting = true; });
    socketService.playerName = _nameController.text.trim();
    socketService.connect('wss://nolpan.onrender.com/ws');

    Future.delayed(const Duration(milliseconds: 1000), () {
      _sub?.cancel();
      _sub = socketService.stream.listen((msg) {
        if (msg['type'] == 'ROOM_UPDATE') {
          _sub?.cancel();
          if (mounted) {
            setState(() { _isConnecting = false; });
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
          }
        } else if (msg['type'] == 'ERROR') {
          _sub?.cancel();
          if (mounted) {
            setState(() { _isConnecting = false; });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg['payload']), backgroundColor: tTerra));
          }
        }
      });

      if (isCreate) {
        socketService.send('CREATE_ROOM', {'name': _nameController.text.trim()});
      } else {
        socketService.send('JOIN_ROOM', {'name': _nameController.text.trim(), 'code': _codeController.text.trim().toUpperCase()});
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Widget _buildInput(String hint, TextEditingController ctrl, {bool isCode = false}) {
    return Container(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: tInk.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: ctrl, maxLength: isCode ? 4 : 12, textCapitalization: isCode ? TextCapitalization.characters : TextCapitalization.words,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: tInk.withOpacity(0.3)), counterText: "", filled: true, fillColor: tSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tInk.withOpacity(0.1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tInk.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: tTeal, width: 2)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCreate = _codeController.text.trim().isEmpty;
    return Scaffold(
      backgroundColor: tBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.all(24.0), child: GestureDetector(onTap: () => Navigator.pop(context), child: Text("<- Back", style: TextStyle(fontWeight: FontWeight.w500, color: tInk.withOpacity(0.7), fontSize: 16)))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text("Who's playing?", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: tInk)),
                      const SizedBox(height: 24),
                      _buildInput("What should we call you?", _nameController),
                      const SizedBox(height: 16),
                      _buildInput("4-letter code (leave blank to create)", _codeController, isCode: true),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: PhysicsButton(
                text: _isConnecting ? "Connecting..." : (isCreate ? "Create New Room" : "Join Room"),
                color: tTeal, shadowColor: const Color(0xFF1A695F), onTap: _isConnecting ? () {} : _handleAction,
              ),
            )
          ],
        ),
      ),
    );
  }
}