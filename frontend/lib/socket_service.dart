import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController>.broadcast();
  
  String? _currentUrl;
  int _retryAttempts = 0;
  bool _isDisposed = false;

  Stream> get stream => _controller.stream;

  void connect(String url) {
    _currentUrl = url;
    _isDisposed = false;
    _establishConnection();
  }

  // PRO HYGIENE: Exponential Backoff Reconnect Logic
  void _establishConnection() {
    if (_currentUrl == null || _isDisposed) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));
      print('Socket connecting...');
      
      _channel!.stream.listen(
        (message) {
          _retryAttempts = 0; // Reset backoff on success
          _controller.add(jsonDecode(message));
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
    
    // Calculates delay: 1s, 2s, 4s, 8s, up to 30s max
    final delay = min(pow(2, _retryAttempts).toInt(), 30);
    print('Socket dropped. Reconnecting in ${delay}s...');
    
    _retryAttempts++;
    Timer(Duration(seconds: delay), _establishConnection);
  }

  void send(String type, Map payload) {
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