import 'package:flutter/material.dart';
import 'core/network/socket_service.dart';
import 'screens/welcome.dart';
import 'games/mosaic/screens/sandbox.dart';
import 'games/mosaic/screens/local_play.dart';
import 'games/mosaic/screens/lobby.dart';

final socketService = SocketService();

const Color tBg = Color(0xFFF9F7F3);
const Color tSurface = Color(0xFFFFFFFF);
const Color tTeal = Color(0xFF2A9D8F);
const Color tTerra = Color(0xFFE76F51);
const Color tInk = Color(0xFF2B2D42);
const Color tGold = Color(0xFFE9C46A);
const Color tIce = Color(0xFFE0E5EC);

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    initialRoute: '/',
    routes: {
      '/': (context) => const WelcomeScreen(),
      '/sandbox': (context) => const SandboxScreen(),
      '/local': (context) => const LocalPlayScreen(),
    },
  ));
}