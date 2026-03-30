import 'package:flutter/material.dart';
import '../../main.dart'; 

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
    Color contentColor = (widget.color == Colors.white || widget.color == tSurface || widget.color == Colors.grey[300]) ? tInk : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        margin: EdgeInsets.only(top: _isPressed ? 6 : 0, bottom: _isPressed ? 0 : 6),
        width: widget.isFullWidth ? double.infinity : null,
        height: 60,
        padding: widget.isFullWidth ? null : const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.isFullWidth ? 12 : 999),
          border: Border(bottom: BorderSide(color: _isPressed ? Colors.transparent : widget.shadowColor, width: _isPressed ? 0 : 6)),
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