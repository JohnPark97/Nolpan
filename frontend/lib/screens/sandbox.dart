import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../main.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({super.key});
  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen> {
  // Scoring
  bool _scoreDissolve = false;
  final GlobalKey _scoreSourceKey = GlobalKey();
  final GlobalKey _scoreTargetKey = GlobalKey();

  // Drafting
  bool _isFlying = false;
  List<bool> _drafted = [false, false, false];
  final GlobalKey _marketKey = GlobalKey();
  final GlobalKey _draftTargetKey = GlobalKey();

  // Penalty
  List<bool> _penalties = List.filled(7, false);
  
  // Selection
  bool _isSelected = false;

  Color _getBaseColor(String colorName) {
    switch (colorName) {
      case 'blue': return tTeal;
      case 'red': return tTerra;
      case 'yellow': return tGold;
      case 'black': return tInk;
      case 'purple': return const Color(0xFF8E44AD);
      default: return Colors.transparent;
    }
  }

  Widget _buildTile(String colorName, {double size = 27, bool isGhost = false, bool empty = false}) {
    if (empty) return Container(width: size, height: size, margin: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)));
    Color bg = _getBaseColor(colorName);
    IconData? icon;
    switch (colorName) {
      case 'blue': icon = Icons.star; break;
      case 'red': icon = Icons.menu; break;
      case 'yellow': icon = Icons.circle; break;
      case 'black': icon = Icons.close; break;
      case 'purple': icon = Icons.diamond; break;
    }
    return Container(
      width: size, height: size, margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: isGhost ? bg.withOpacity(0.15) : bg,
        borderRadius: BorderRadius.circular(4),
        boxShadow: !isGhost ? [BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 3))] : [],
      ),
      child: Center(child: Icon(icon, size: size * 0.45, color: Colors.white.withOpacity(0.5))),
    );
  }

  void _triggerScore() async {
    final RenderBox? startBox = _scoreSourceKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = _scoreTargetKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;

    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);

    setState(() => _scoreDissolve = true);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, val, child) {
          double dx = startPos.dx + (endPos.dx - startPos.dx) * val;
          double dy = startPos.dy + (endPos.dy - startPos.dy) * val;
          return Positioned(left: dx, top: dy, child: _buildTile('blue'));
        },
        onEnd: () => entry?.remove()
      )
    );
    Overlay.of(context).insert(entry);
    
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _scoreDissolve = false);
  }

  void _triggerFlight() async {
    if (_isFlying) return;
    setState(() { _isFlying = true; _drafted = [false, false, false]; });

    final RenderBox? startBox = _marketKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = _draftTargetKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) { setState(() => _isFlying = false); return; }

    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutSine,
        builder: (context, val, child) {
          double dx = startPos.dx + (endPos.dx - startPos.dx) * val;
          double dy = startPos.dy + (endPos.dy - startPos.dy) * val - (math.sin(val * math.pi) * 60);
          return Positioned(
            left: dx + 20, top: dy + 10,
            child: Transform.scale(
              scale: val < 0.5 ? 1.0 + val * 0.3 : 1.3 - (val - 0.5) * 0.6,
              child: Row(children: List.generate(3, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: _buildTile('purple', size: 24))))
            )
          );
        },
        onEnd: () async {
          entry?.remove();
          for (int i = 0; i < 3; i++) {
            if (!mounted) return;
            setState(() => _drafted[i] = true);
            HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 80));
          }
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) setState(() { _isFlying = false; _drafted = [false, false, false]; });
        }
      )
    );
    Overlay.of(context).insert(entry);
  }

  void _triggerPenalty() async {
    setState(() => _penalties = List.filled(7, false));
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      setState(() => _penalties[i] = true);
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      appBar: AppBar(
        backgroundColor: tInk, elevation: 0,
        title: const Text("PHYSICS AUDIT v1.2", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeading("1. SCORING: GLOBALKEY SNAP"),
          _buildCard(Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: List.generate(5, (idx) {
                Widget tile = _buildTile('blue');
                if (idx == 4) {
                  return Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), SizedBox(key: _scoreSourceKey, child: AnimatedOpacity(opacity: _scoreDissolve ? 0.0 : 1.0, duration: const Duration(milliseconds: 100), child: tile))]);
                }
                return Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), AnimatedScale(scale: _scoreDissolve ? 0.0 : 1.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInBack, child: AnimatedOpacity(opacity: _scoreDissolve ? 0.0 : 1.0, duration: const Duration(milliseconds: 400), child: tile))]);
              })),
              const SizedBox(width: 40),
              SizedBox(key: _scoreTargetKey, child: Stack(alignment: Alignment.center, children: [_buildTile('blue', isGhost: true), AnimatedOpacity(opacity: 0.0, duration: Duration.zero, child: _buildTile('blue'))])),
            ]),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger GlobalKey Flight", color: tTeal, shadowColor: const Color(0xFF1E7066), onTap: _triggerScore),
          ])),

          _buildHeading("2. DRAFTING: ARC FLIGHT + POP-IN"),
          _buildCard(Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  key: _marketKey, width: 70, height: 70, decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                  child: Center(child: Wrap(spacing: 2, runSpacing: 2, children: List.generate(4, (i) => AnimatedOpacity(opacity: (i < 3 && _isFlying) ? 0.0 : 1.0, duration: const Duration(milliseconds: 100), child: _buildTile('purple', size: 18)))))
                ),
                Container(
                  key: _draftTargetKey,
                  child: Row(children: List.generate(3, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), AnimatedScale(scale: _drafted[i] ? 1.0 : 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack, child: _buildTile('purple'))]))))
                )
              ]
            ),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Market Arc", color: tGold, shadowColor: const Color(0xFFB59A53), onTap: _triggerFlight),
          ])),

          _buildHeading("3. SELECTION: PHYSICAL LIFT"),
          _buildCard(Column(children: [
            GestureDetector(
              onTap: () { setState(() => _isSelected = !_isSelected); HapticFeedback.selectionClick(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150), curve: Curves.easeOutBack,
                transform: _isSelected ? Matrix4.translationValues(0, -6.0, 0) : Matrix4.identity(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: tTeal, borderRadius: BorderRadius.circular(6), boxShadow: _isSelected ? [const BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 8))] : [const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))]),
                  child: const Icon(Icons.star, color: Colors.white70),
                )
              ),
            ),
            const SizedBox(height: 32),
            PhysicsButton(text: "Toggle Lift", color: tIce, shadowColor: const Color(0xFFB5BBC4), onTap: () { setState(() => _isSelected = !_isSelected); HapticFeedback.selectionClick(); }),
          ])),

          _buildHeading("4. PENALTY: THE SHATTER"),
          _buildCard(Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(7, (idx) {
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(children: [
                Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), AnimatedContainer(duration: const Duration(milliseconds: 400), curve: Curves.bounceOut, transform: _penalties[idx] ? Matrix4.identity() : Matrix4.translationValues(0, -40, 0), child: AnimatedOpacity(opacity: _penalties[idx] ? 1.0 : 0.0, duration: const Duration(milliseconds: 200), child: _buildTile('red')))]),
                const SizedBox(height: 4), Text(['-1','-1','-2','-2','-2','-3','-3'][idx], style: const TextStyle(color: tTerra, fontWeight: FontWeight.bold, fontSize: 12))
              ]));
            })),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Penalty Drop", color: tTerra, shadowColor: const Color(0xFFB3563F), onTap: _triggerPenalty),
          ])),
          const SizedBox(height: 40),
        ],
      )
    );
  }

  Widget _buildHeading(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 24, left: 4), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 1.5, fontSize: 12)));
  Widget _buildCard(Widget child) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: child);
}