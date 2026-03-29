import 'package:flutter/material.dart';
import 'socket_service.dart';
import 'screens/welcome.dart';
import 'screens/sandbox.dart';
import 'screens/local_play.dart';

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
    initialRoute: '/local', // Boot directly to offline QA
    routes: {
      '/': (context) => const WelcomeScreen(),
      '/sandbox': (context) => const SandboxScreen(),
      '/local': (context) => const LocalPlayScreen(),
    },
  ));
}

class PhysicsButton extends StatefulWidget {
  final String text;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;
  final bool isFullWidth;
  final Widget? customChild;

  const PhysicsButton({
    super.key, 
    required this.text, 
    required this.color, 
    required this.shadowColor, 
    required this.onTap,
    this.isFullWidth = true,
    this.customChild,
  });

  @override
  State<PhysicsButton> createState() => _PhysicsButtonState();
}

class _PhysicsButtonState extends State<PhysicsButton> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    Color contentColor = widget.color == Colors.white || widget.color == tSurface ? tInk : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        margin: EdgeInsets.only(top: _isPressed ? 4 : 0, bottom: _isPressed ? 0 : 4),
        width: widget.isFullWidth ? double.infinity : null,
        height: 60,
        padding: widget.isFullWidth ? null : const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.isFullWidth ? 12 : 999),
          border: Border(bottom: BorderSide(color: _isPressed ? Colors.transparent : widget.shadowColor, width: 4)),
        ),
        child: Center(
          child: widget.customChild ?? Text(
            widget.text, 
            style: TextStyle(color: contentColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)
          ),
        ),
      ),
    );
  }
}