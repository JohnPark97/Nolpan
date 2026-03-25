import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  late WebSocketChannel _channel;
  
  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      print("Server: " + data['type']);
    });
  }

  void createRoom(String name) {
    final msg = jsonEncode({
      "type": "CREATE_ROOM",
      "payload": {"name": name}
    });
    _channel.sink.add(msg);
  }
}