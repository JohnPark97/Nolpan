import 'package:flutter/material.dart';
import '../main.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({super.key});
  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen> {
  // Scoring State
  bool _scoreSlide = false;
  bool _scoreDissolve = false;

  // Drafting State
  List<bool> _drafted = [false, false, false];

  // Penalty State
  List<bool> _penalties = List.filled(7, false);

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
      await Future.delayed(const Duration(milliseconds: 150));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      appBar: AppBar(
        backgroundColor: tInk,
        elevation: 0,
        title: const Text("ANIMATION PREVIEW", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
                  tile = AnimatedContainer(duration: const Duration(milliseconds: 400), curve: Curves.easeInCubic, transform: _scoreSlide ? Matrix4.translationValues(50.0, 0, 0) : Matrix4.identity(), child: tile);
                }
                return Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), tile]);
              })),
              const SizedBox(width: 40),
              Stack(alignment: Alignment.center, children: [_buildTile('blue', isGhost: true), AnimatedOpacity(opacity: _scoreSlide ? 1.0 : 0.0, duration: const Duration(milliseconds: 200), child: _buildTile('blue'))]),
            ]),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Score", color: tTeal, shadowColor: const Color(0xFF1E7066), onTap: _triggerScore),
          ])),

          _buildHeading("2. DRAFTING: STAGGERED POP-IN"),
          _buildCard(Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (idx) {
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), AnimatedScale(scale: _drafted[idx] ? 1.0 : 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack, child: _buildTile('purple'))]));
            })),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Draft (3 Tiles)", color: tGold, shadowColor: const Color(0xFFB59A53), onTap: _triggerDraft),
          ])),

          _buildHeading("3. PENALTY: THE SHATTER"),
          _buildCard(Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(7, (idx) {
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(children: [
                Stack(alignment: Alignment.center, children: [_buildTile("", empty: true), AnimatedContainer(duration: const Duration(milliseconds: 400), curve: Curves.easeOutBounce, transform: _penalties[idx] ? Matrix4.identity() : Matrix4.translationValues(0, -40, 0), child: AnimatedOpacity(opacity: _penalties[idx] ? 1.0 : 0.0, duration: const Duration(milliseconds: 200), child: _buildTile('red')))]),
                const SizedBox(height: 4), Text(['-1','-1','-2','-2','-2','-3','-3'][idx], style: const TextStyle(color: tTerra, fontWeight: FontWeight.bold, fontSize: 12))
              ]));
            })),
            const SizedBox(height: 32),
            PhysicsButton(text: "Trigger Penalty Dump", color: tTerra, shadowColor: const Color(0xFFB3563F), onTap: _triggerPenalty),
          ])),
        ],
      )
    );
  }

  Widget _buildHeading(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 24, left: 4), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 1.5, fontSize: 12)));
  Widget _buildCard(Widget child) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: child);
}