import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // BUGFIX: Required for HapticFeedback
import 'dart:math' as math;
import '../main.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({super.key});
  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen> {
  // 1. Scoring State
  bool _scoreSlide = false;
  bool _scoreDissolve = false;

  // 2. Drafting State
  List<bool> _drafted = [false, false, false];

  // 3. Penalty State
  List<bool> _penalties = List.filled(7, false);

  // 4. Flight State
  bool _isFlying = false;
  List<bool> _flightLanded = [false, false, false];
  final GlobalKey _kilnKey = GlobalKey();
  final GlobalKey _stairKey = GlobalKey();

  // 5. Selection Pulse State
  bool _isSelected = false;

  // 6. Mascot State
  double _nollieY = -60.0; // Hidden below clipping box
  String _nollieFace = '🐶';
  Color _nollieColor = Colors.white;

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
    setState(() { _scoreSlide = false; _scoreDissolve = false; });
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() { _scoreSlide = true; _scoreDissolve = true; });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() { _scoreSlide = false; _scoreDissolve = false; });
  }

  void _triggerDraft() async {
    setState(() => _drafted = [false, false, false]);
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      setState(() => _drafted[i] = true);
      await Future.delayed(const Duration(milliseconds: 100)); // Stagger
    }
  }

  void _triggerPenalty() async {
    setState(() => _penalties = List.filled(7, false));
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      setState(() => _penalties[i] = true);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _triggerFlight() async {
    if (_isFlying) return;
    setState(() { _isFlying = true; _flightLanded = [false, false, false]; });

    final RenderBox? startBox = _kilnKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = _stairKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) {
      setState(() => _isFlying = false);
      return;
    }

    final Offset startPos = startBox.localToGlobal(Offset.zero);
    final Offset endPos = endBox.localToGlobal(Offset.zero);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutSine, // Smooth arc timing
        builder: (context, val, child) {
          // Math: Linear X, Parabolic Y for gravity arc
          double dx = startPos.dx + (endPos.dx - startPos.dx) * val;
          double dy = startPos.dy + (endPos.dy - startPos.dy) * val - (math.sin(val * math.pi) * 80);
          return Positioned(
            left: dx + 20, // Center alignment offset
            top: dy + 20,
            child: Transform.scale(
              scale: val < 0.5 ? 1.0 + val * 0.3 : 1.3 - (val - 0.5) * 0.6,
              child: Row(
                children: List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: _buildTile('purple', size: 24)
                ))
              )
            )
          );
        },
        onEnd: () async {
          entry?.remove();
          // Trigger the Pop-In landing cascade
          for (int i = 0; i < 3; i++) {
            if (!mounted) return;
            setState(() => _flightLanded[i] = true);
            HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 80)); // Fast Stagger
          }
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) setState(() { _isFlying = false; _flightLanded = [false, false, false]; });
        }
      )
    );
    Overlay.of(context).insert(entry);
  }

  void _triggerNollie(bool isError) async {
    setState(() {
      _nollieFace = isError ? '🥸' : '🥳';
      _nollieColor = isError ? Colors.red[50]! : Colors.green[50]!;
      _nollieY = 20.0; // Peek up
    });
    if (isError) HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _nollieY = -60.0); // Hide
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      appBar: AppBar(
        backgroundColor: tInk,
        elevation: 0,
        title: const Text("ANIMATION PREVIEW v1.1", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 1. SCORING
          _buildHeading("1. SCORING: SLIDE & DISSOLVE"),
          _buildCard(Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: List.generate(5, (idx) {
                Widget tile = _buildTile('blue');
                if (idx < 4) {
                  tile = AnimatedScale(
                    scale: _scoreDissolve ? 0.0 : 1.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInBack,
                    child: AnimatedOpacity(opacity: _scoreDissolve ? 0.0 : 1.0, duration: const Duration(milliseconds: 400), child: tile)
                  );
                } else {
                  // CORRECTED PHYSICS: Elastic Snap
                  tile = AnimatedContainer(duration: const Duration(milliseconds: 500), curve: Curves.elasticOut, transform: _scoreSlide ? Matrix4.translationValues(55.0, 0, 0) : Matrix4.identity(), child: tile);
                }
                return Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), tile]);
              })),
              const SizedBox(width: 40),
              Stack(alignment: Alignment.center, children: [_buildTile('blue', isGhost: true), AnimatedOpacity(opacity: _scoreSlide ? 1.0 : 0.0, duration: const Duration(milliseconds: 200), child: _buildTile('blue'))]),
            ]),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Score Snap", color: tTeal, shadowColor: const Color(0xFF1E7066), onTap: _triggerScore),
          ])),

          // 2. DRAFTING POP-IN
          _buildHeading("2. DRAFTING: STAGGERED POP-IN"),
          _buildCard(Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (idx) {
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), AnimatedScale(scale: _drafted[idx] ? 1.0 : 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack, child: _buildTile('purple'))]));
            })),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Pop-In (3 Tiles)", color: tGold, shadowColor: const Color(0xFFB59A53), onTap: _triggerDraft),
          ])),

          // 3. PENALTY SHATTER
          _buildHeading("3. PENALTY: THE SHATTER"),
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

          // 4. MARKET FLIGHT ARC
          _buildHeading("4. DRAFTING: MARKET FLIGHT ARC"),
          _buildCard(Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  key: _kilnKey,
                  width: 70, height: 70, decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                  child: Center(child: Wrap(spacing: 2, runSpacing: 2, children: List.generate(4, (i) => AnimatedOpacity(opacity: (i < 3 && _isFlying) ? 0.0 : 1.0, duration: const Duration(milliseconds: 100), child: _buildTile('purple', size: 18)))))
                ),
                Container(
                  key: _stairKey,
                  child: Row(children: List.generate(3, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), AnimatedScale(scale: _flightLanded[i] ? 1.0 : 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack, child: _buildTile('purple'))]))))
                )
              ]
            ),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Arc Flight", color: tInk, shadowColor: const Color(0xFF151621), onTap: _triggerFlight),
          ])),

          // 5. TILE SELECTION PULSE
          _buildHeading("5. INTERACTION: SELECTION PULSE"),
          _buildCard(Column(children: [
            GestureDetector(
              onTap: () => setState(() => _isSelected = !_isSelected),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                transform: _isSelected ? Matrix4.translationValues(0, -6.0, 0) : Matrix4.identity(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: tTeal,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _isSelected ? [const BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 8))] : [const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
                  ),
                  child: const Icon(Icons.star, color: Colors.white70),
                )
              ),
            ),
            const SizedBox(height: 32),
            PhysicsButton(text: "Toggle Physical Lift", color: tIce, shadowColor: const Color(0xFFB5BBC4), onTap: () => setState(() => _isSelected = !_isSelected)),
          ])),

          // 6. MASCOT FEEDBACK
          _buildHeading("6. MASCOT: NOLLIE OVERLAY"),
          _buildCard(Column(children: [
            // Mock UI boundary to hide Nollie
            ClipRect(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(height: 100, width: double.infinity, color: Colors.transparent),
                  // Nollie Sprite
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    bottom: _nollieY,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(color: _nollieColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))]),
                      child: Text(_nollieFace, style: const TextStyle(fontSize: 42)),
                    )
                  ),
                  // Mock Top of Board
                  Positioned(bottom: 0, child: Container(height: 30, width: 200, decoration: BoxDecoration(color: tBg, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)), border: Border.all(color: Colors.black12)))),
                ]
              )
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: PhysicsButton(text: "Error", color: tTerra, shadowColor: const Color(0xFFB3563F), onTap: () => _triggerNollie(true))),
                const SizedBox(width: 12),
                Expanded(child: PhysicsButton(text: "Victory", color: Colors.green, shadowColor: Colors.green[800]!, onTap: () => _triggerNollie(false))),
              ]
            )
          ])),

          const SizedBox(height: 40),
        ],
      )
    );
  }

  Widget _buildHeading(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 24, left: 4), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 1.5, fontSize: 12)));
  Widget _buildCard(Widget child) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: child);
}