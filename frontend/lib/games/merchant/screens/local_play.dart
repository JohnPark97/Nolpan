import 'package:flutter/material.dart';

// --- DATA MODELS ---

class GemType {
  final String name;
  final Color color;
  final IconData? icon;
  final String? textIcon;
  final Gradient? gradient;

  const GemType(this.name, this.color, {this.icon, this.textIcon, this.gradient});
}

class GemPalette {
  static const GemType teal = GemType('Emerald', Color(0xFF2A9D8F), icon: Icons.star);
  static const GemType amethyst = GemType('Amethyst', Color(0xFF8E44AD), icon: Icons.diamond);
  static const GemType yellow = GemType('Gold', Color(0xFFE9C46A), icon: Icons.circle);
  static const GemType red = GemType('Ruby', Color(0xFFE76F51), icon: Icons.menu);
  static const GemType blue = GemType('Sapphire', Color(0xFF264653), icon: Icons.close);
  static const GemType wild = GemType(
    'Wild', 
    Color(0xFFD4AF37), 
    textIcon: 'W',
    gradient: LinearGradient(colors: [Color(0xFFF1C40F), Color(0xFFB8860B)], begin: Alignment.topLeft, end: Alignment.bottomRight)
  );

  static const List<GemType> stdGems = [teal, amethyst, yellow, red, blue];
}

class Cost {
  final GemType gem;
  final int count;
  const Cost(this.gem, this.count);
}

// --- MAIN SCREEN ---

class GemCrafterScreen extends StatelessWidget {
  const GemCrafterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. THE SKY (flex-shrink-0)
            _buildSky(),
            
            // 2. THE PENTHOUSE (flex-shrink-0)
            _buildNobles(),

            // 3. THE MARKET (flex-1 min-h-0)
            Expanded(child: _buildMarket()),

            // 4. THE BANK (flex-shrink-0)
            _buildBank(),

            // 5. THE DASHBOARD (flex-shrink-0)
            _buildDashboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSky() {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF2A9D8F), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0,1), blurRadius: 2)]),
                child: const Text("CURRENT TURN: PLAYER 1", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              Text("GEM CRAFTER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Expanded(child: OpponentCard(name: "Jahn", avatar: "J", score: 14, engine: [2, 0, 4, 1, 0], wallet: [1, 0, 2, 0, 0, 1])),
              SizedBox(width: 6),
              Expanded(child: OpponentCard(name: "Bee", avatar: "B", score: 8, engine: [0, 3, 1, 2, 2], wallet: [0, 2, 0, 1, 1, 0])),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNobles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          NobleTile(points: 3, req: [Cost(GemPalette.teal, 4), Cost(GemPalette.amethyst, 4)]),
          SizedBox(width: 8),
          NobleTile(points: 3, req: [Cost(GemPalette.red, 3), Cost(GemPalette.blue, 3), Cost(GemPalette.yellow, 3)]),
          SizedBox(width: 8),
          NobleTile(points: 3, req: [Cost(GemPalette.amethyst, 4), Cost(GemPalette.blue, 4)]),
        ],
      ),
    );
  }

  Widget _buildMarket() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Decks Column
          SizedBox(
            width: 48,
            child: Column(
              children: const [
                Expanded(child: DeckCard(tier: 3, count: 12, textColor: Colors.lightBlueAccent)),
                SizedBox(height: 6),
                Expanded(child: DeckCard(tier: 2, count: 24, textColor: Colors.amberAccent)),
                SizedBox(height: 6),
                Expanded(child: DeckCard(tier: 1, count: 36, textColor: Color(0xFF2A9D8F))),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Cards Grid
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Expanded(child: MarketCard(gem: GemPalette.blue, points: 4, costs: [Cost(GemPalette.amethyst, 6), Cost(GemPalette.red, 3)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.teal, points: 5, costs: [Cost(GemPalette.teal, 7), Cost(GemPalette.yellow, 3)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.amethyst, points: 3, costs: [Cost(GemPalette.blue, 5), Cost(GemPalette.red, 3)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.red, points: 4, costs: [Cost(GemPalette.amethyst, 7)])),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Row(
                    children: const [
                      Expanded(child: MarketCard(gem: GemPalette.yellow, points: 2, costs: [Cost(GemPalette.teal, 4), Cost(GemPalette.blue, 2)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.red, points: 1, costs: [Cost(GemPalette.yellow, 3), Cost(GemPalette.amethyst, 2)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.blue, points: 2, costs: [Cost(GemPalette.red, 5)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.amethyst, points: 2, costs: [Cost(GemPalette.teal, 4), Cost(GemPalette.red, 1)])),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Row(
                    children: const [
                      Expanded(child: MarketCard(gem: GemPalette.teal, points: 0, costs: [Cost(GemPalette.blue, 1), Cost(GemPalette.amethyst, 2)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.amethyst, points: 0, costs: [Cost(GemPalette.yellow, 2), Cost(GemPalette.red, 2)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.red, points: 0, costs: [Cost(GemPalette.teal, 1), Cost(GemPalette.amethyst, 3)])),
                      SizedBox(width: 6),
                      Expanded(child: MarketCard(gem: GemPalette.blue, points: 0, costs: [Cost(GemPalette.yellow, 1), Cost(GemPalette.teal, 1), Cost(GemPalette.red, 1)])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBank() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          BankToken(gem: GemPalette.teal, count: 4),
          SizedBox(width: 8),
          BankToken(gem: GemPalette.amethyst, count: 2),
          SizedBox(width: 8),
          BankToken(gem: GemPalette.yellow, count: 5),
          SizedBox(width: 8),
          BankToken(gem: GemPalette.red, count: 4),
          SizedBox(width: 8),
          BankToken(gem: GemPalette.blue, count: 0),
          SizedBox(width: 8),
          BankToken(gem: GemPalette.wild, count: 5),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, offset: Offset(0, -4), blurRadius: 20)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text("SCORE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 1.5)),
                  const SizedBox(width: 8),
                  const Text("12", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2A9D8F), height: 1)),
                ],
              ),
              Row(
                children: [
                  Text("RESERVED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 1.5)),
                  const SizedBox(width: 6),
                  Container(width: 20, height: 28, decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber[400]!, width: 2))),
                  const SizedBox(width: 4),
                  Container(width: 20, height: 28, decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blueGrey[200]!))),
                  const SizedBox(width: 4),
                  Container(width: 20, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blueGrey[300]!, style: BorderStyle.solid))),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: EngineBlock(gem: GemPalette.teal, count: 4)),
              SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemPalette.amethyst, count: 2)),
              SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemPalette.yellow, count: 3)),
              SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemPalette.red, count: 1)),
              SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemPalette.blue, count: 2)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF9F7F3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey[200]!)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("TOKENS IN HAND", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 1.5)),
                    Text("8 / 10", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey[500])),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const WalletToken(gem: GemPalette.teal),
                    const Align(widthFactor: 0.7, child: WalletToken(gem: GemPalette.teal)),
                    const Align(widthFactor: 0.7, child: WalletToken(gem: GemPalette.amethyst)),
                    const Align(widthFactor: 0.7, child: WalletToken(gem: GemPalette.yellow)),
                    const Align(widthFactor: 0.7, child: WalletToken(gem: GemPalette.red)),
                    const Align(widthFactor: 0.7, child: WalletToken(gem: GemPalette.red)),
                    const Align(widthFactor: 0.7, child: WalletToken(gem: GemPalette.wild)),
                    const Align(widthFactor: 0.7, child: WalletToken(gem: GemPalette.wild)),
                    const Spacer(),
                    Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueGrey[300]!))),
                    const SizedBox(width: 4),
                    Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueGrey[300]!))),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- WIDGET COMPONENTS ---

Widget _buildGemIcon(GemType gem, double size, {Color? color}) {
  if (gem.textIcon != null) {
    return Text(gem.textIcon!, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color ?? Colors.white, height: 1.0));
  }
  return Icon(gem.icon, size: size, color: color ?? Colors.white);
}

class OpponentCard extends StatelessWidget {
  final String name;
  final String avatar;
  final int score;
  final List<int> engine;
  final List<int> wallet;

  const OpponentCard({super.key, required this.name, required this.avatar, required this.score, required this.engine, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueGrey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 8, backgroundColor: const Color(0xFF2A9D8F), child: Text(avatar, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 4),
                  Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ],
              ),
              Text(score.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF2A9D8F))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ...List.generate(5, (i) {
                int c = engine[i];
                return Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: GemPalette.stdGems[i].color.withOpacity(c > 0 ? 1.0 : 0.2), borderRadius: BorderRadius.circular(2)),
                  child: Center(child: Text(c > 0 ? c.toString() : "", style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold))),
                );
              }),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              int c = wallet[i];
              GemType g = i < 5 ? GemPalette.stdGems[i] : GemPalette.wild;
              return Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: g.gradient == null ? g.color.withOpacity(c > 0 ? 1.0 : 0.2) : null,
                  gradient: g.gradient != null && c > 0 ? g.gradient : null,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(c > 0 ? c.toString() : "", style: const TextStyle(fontSize: 6, color: Colors.white, fontWeight: FontWeight.bold))),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class NobleTile extends StatelessWidget {
  final int points;
  final List<Cost> req;
  const NobleTile({super.key, required this.points, required this.req});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFD4AF37), width: 2), boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(points.toString(), style: TextStyle(color: Colors.yellow[400], fontWeight: FontWeight.w900, fontSize: 16, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: req.map((r) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                children: [
                  Text(r.count.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, height: 1)),
                  Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 1), decoration: BoxDecoration(color: r.gem.color, borderRadius: BorderRadius.circular(1))),
                ],
              ),
            )).toList(),
          )
        ],
      ),
    );
  }
}

class DeckCard extends StatelessWidget {
  final int tier;
  final int count;
  final Color textColor;
  const DeckCard({super.key, required this.tier, required this.count, required this.textColor});

  @override
  Widget build(BuildContext context) {
    String numeral = tier == 3 ? "III" : (tier == 2 ? "II" : "I");
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueGrey[600]!), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 2)]),
      child: Stack(
        children: [
          Center(child: Text(numeral, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -2))),
          Positioned(bottom: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(2)), child: Text(count.toString(), style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}

class MarketCard extends StatelessWidget {
  final GemType gem;
  final int points;
  final List<Cost> costs;
  const MarketCard({super.key, required this.gem, required this.points, required this.costs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueGrey[200]!), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 2)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(points > 0 ? points.toString() : "", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey[700], height: 1)),
              _buildGemIcon(gem, 14, color: gem.color),
            ],
          ),
          Wrap(
            spacing: 2, runSpacing: 2,
            children: costs.map((c) => Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: c.gem.color, shape: BoxShape.circle),
              child: Center(child: Text(c.count.toString(), style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900))),
            )).toList(),
          )
        ],
      ),
    );
  }
}

class BankToken extends StatelessWidget {
  final GemType gem;
  final int count;
  const BankToken({super.key, required this.gem, required this.count});

  @override
  Widget build(BuildContext context) {
    bool empty = count == 0;
    return Opacity(
      opacity: empty ? 0.3 : 1.0,
      child: Column(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: gem.gradient == null ? gem.color : null, gradient: gem.gradient, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]),
            child: Center(child: _buildGemIcon(gem, 18)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.blueGrey[200], borderRadius: BorderRadius.circular(12)),
            child: Text(count.toString(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey[600], height: 1)),
          )
        ],
      ),
    );
  }
}

class EngineBlock extends StatelessWidget {
  final GemType gem;
  final int count;
  const EngineBlock({super.key, required this.gem, required this.count});

  @override
  Widget build(BuildContext context) {
    bool active = count > 0;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: active ? gem.color : Colors.blueGrey[100],
        borderRadius: BorderRadius.circular(8),
        border: active ? const Border(bottom: BorderSide(color: Colors.black26, width: 3)) : Border.all(color: Colors.blueGrey[200]!, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.blueGrey[300], height: 1)),
          if (active) Padding(padding: const EdgeInsets.only(top: 2), child: _buildGemIcon(gem, 8)),
        ],
      ),
    );
  }
}

class WalletToken extends StatelessWidget {
  final GemType gem;
  const WalletToken({super.key, required this.gem});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: gem.gradient == null ? gem.color : null, gradient: gem.gradient, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 2)]),
      child: Center(child: _buildGemIcon(gem, 10)),
    );
  }
}