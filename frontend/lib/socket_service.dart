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
  Map<String, dynamic>? lastRoomUpdate;
  Timer? _heartbeat;
  
  String? playerName;
  String? currentRoomCode;

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
      
      if (playerName != null && currentRoomCode != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          send('RECONNECT', {'name': playerName, 'code': currentRoomCode});
        });
      }

      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 10), (timer) {
        send('PING', {});
      });

      _channel!.stream.listen(
        (message) {
          _retryAttempts = 0;
          final decoded = jsonDecode(message);
          if (decoded['payload'] is String) { decoded['payload'] = jsonDecode(decoded['payload']); }
          
          if (decoded['type'] == 'ROOM_UPDATE') { 
            lastRoomUpdate = decoded; 
            currentRoomCode = decoded['payload']['code'];
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
    _heartbeat?.cancel();
    final delay = min(pow(2, _retryAttempts).toInt(), 30);
    _retryAttempts++;
    Timer(Duration(seconds: delay), _establishConnection);
  }

  void send(String type, Map<String, dynamic> payload) {
    try {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({"type": type, "payload": payload}));
      }
    } catch (e) {
      _handleDisconnect(); 
    }
  }

  void dispose() {
    _isDisposed = true;
    _heartbeat?.cancel();
    _controller.close();
    _channel?.sink.close();
  }
}