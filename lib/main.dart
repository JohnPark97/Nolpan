import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

// --- GLOBAL SINGLETON ---
final socketService = SocketService();

void main() {
  runApp(const NolpanApp());
}

class NolpanApp extends StatelessWidget {
  const NolpanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nolpan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF9F7F3),
        primaryColor: const Color(0xFF2A9D8F),
      ),
      home: const GatewayScreen(),
    );
  }
}

// --- GATEWAY SCREEN ---
class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});
  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final TextEditingController _nameController = TextEditingController();

  void _createRoom() {
    if (_nameController.text.trim().isEmpty) return;
    socketService.connect('wss://nolpan.onrender.com/ws');
    socketService.send('CREATE_ROOM', {'name': _nameController.text.trim()});
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

// --- LOBBY SCREEN ---
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String roomCode = "WAIT...";
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = socketService.stream.listen((message) {
      if (message['type'] == 'ROOM_CREATED') {
        setState(() { roomCode = message['payload']['code']; });
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Gathering Room", style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Text(roomCode, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Color(0xFF2A9D8F), letterSpacing: 8)),
            const SizedBox(height: 64),
            const CircularProgressIndicator(color: Color(0xFFE9C46A)),
          ],
        ),
      ),
    );
  }
}

// --- SOCKET SERVICE ---
class SocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  String? _currentUrl;
  int _retryAttempts = 0;
  bool _isDisposed = false;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect(String url) {
    if (_currentUrl == url && _channel != null) return;
    _currentUrl = url;
    _isDisposed = false;
    _establishConnection();
  }

  void _establishConnection() {
    if (_currentUrl == null || _isDisposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));
      _channel!.stream.listen(
        (message) {
          _retryAttempts = 0;
          final decoded = jsonDecode(message);
          if (decoded['payload'] is String) {
            decoded['payload'] = jsonDecode(decoded['payload']);
          }
          _controller.add(decoded);
        },
        onDone: _handleDisconnect,
        onError: (error) => _handleDisconnect(),
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (_isDisposed) return;
    final delay = min(pow(2, _retryAttempts).toInt(), 30);
    _retryAttempts++;
    Timer(Duration(seconds: delay), _establishConnection);
  }

  void send(String type, Map<String, dynamic> payload) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"type": type, "payload": payload}));
    }
  }

  void dispose() {
    _isDisposed = true;
    _controller.close();
    _channel?.sink.close();
  }
}