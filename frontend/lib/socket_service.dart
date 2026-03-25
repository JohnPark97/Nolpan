import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  String? _currentUrl;
  int _retryAttempts = 0;
  bool _isDisposed = false;
  
  // THE FIX: Cache the last known room state to prevent loading race conditions
  Map<String, dynamic>? lastRoomUpdate;

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
          
          // Cache the state before broadcasting
          if (decoded['type'] == 'ROOM_UPDATE') {
            lastRoomUpdate = decoded;
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