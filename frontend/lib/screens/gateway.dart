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

  void _handleAction(bool isCreate) {
    if (_nameController.text.trim().isEmpty) return;
    if (!isCreate && _codeController.text.trim().length != 4) return;

    setState(() { _isConnecting = true; });
    socketService.connect('wss://nolpan.onrender.com/ws');

    // Wait a brief moment for connection to establish
    Future.delayed(const Duration(milliseconds: 1000), () {
      
      // Listen for Success OR Error from the server
      _sub?.cancel();
      _sub = socketService.stream.listen((msg) {
        if (msg['type'] == 'ROOM_UPDATE') {
          _sub?.cancel();
          if (mounted) {
            setState(() { _isConnecting = false; });
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
          }
        } else if (msg['type'] == 'ERROR') {
          _sub?.cancel();
          if (mounted) {
            setState(() { _isConnecting = false; });
            // Show the error message from the Go server
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg['payload'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              )
            );
          }
        }
      });

      // Send the request
      if (isCreate) {
        socketService.send('CREATE_ROOM', {'name': _nameController.text.trim()});
      } else {
        socketService.send('JOIN_ROOM', {
          'name': _nameController.text.trim(),
          'code': _codeController.text.trim().toUpperCase()
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Text("NOLPAN", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2A9D8F), letterSpacing: 4)),
              const SizedBox(height: 48),
              _buildInput("Your Name", _nameController),
              const SizedBox(height: 16),
              const Divider(height: 40),
              ElevatedButton(
                onPressed: _isConnecting ? null : () => _handleAction(true),
                style: _btnStyle(const Color(0xFF2A9D8F)),
                child: _isConnecting ? _loader() : const Text("CREATE NEW ROOM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 24),
              const Text("OR JOIN EXISTING", style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 2)),
              const SizedBox(height: 16),
              _buildInput("4-Letter Code", _codeController, isCode: true),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isConnecting ? null : () => _handleAction(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  side: const BorderSide(color: Color(0xFF2A9D8F), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("JOIN ROOM", style: TextStyle(color: Color(0xFF2A9D8F), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isCode = false}) {
    return TextField(
      controller: ctrl,
      textAlign: TextAlign.center,
      maxLength: isCode ? 4 : 12,
      textCapitalization: isCode ? TextCapitalization.characters : TextCapitalization.words,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: isCode ? 8 : 0),
      decoration: InputDecoration(
        hintText: label,
        counterText: "",
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  ButtonStyle _btnStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color, minimumSize: const Size(double.infinity, 60),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 0,
  );

  Widget _loader() => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
}