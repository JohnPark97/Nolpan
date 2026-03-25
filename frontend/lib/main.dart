import 'package:flutter/material.dart';
import 'socket_service.dart';
import 'screens/welcome.dart';

final socketService = SocketService();

// STRICT DESIGN TOKENS (tIce officially included!)
const Color tBg = Color(0xFFF9F7F3);
const Color tSurface = Color(0xFFFFFFFF);
const Color tTeal = Color(0xFF2A9D8F);
const Color tTerra = Color(0xFFE76F51);
const Color tInk = Color(0xFF2B2D42);
const Color tGold = Color(0xFFE9C46A);
const Color tIce = Color(0xFFE0E5EC); // <-- THE MISSING TOKEN

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: WelcomeScreen(),
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
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
          child: widget.customChild ?? Text(widget.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
        ),
      ),
    );
  }
}