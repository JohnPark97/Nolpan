import 'package:flutter/material.dart';
import 'socket_service.dart';
import 'screens/gateway.dart';

// GLOBAL SINGLETON: Keeps connection alive across screens
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