import 'package:flutter/material.dart';
import 'dart:math' as math;

// --- 1. STRICT DATA MODELS ---

enum GemType { emerald, amethyst, yellow, ruby, sapphire, gold }

extension GemTypeExt on GemType {
  Color get color {
    switch (this) {
      case GemType.emerald: return const Color(0xFF2A9D8F);
      case GemType.amethyst: return const Color(0xFF8E44AD);
      case GemType.yellow: return const Color(0xFFE9C46A);
      case GemType.ruby: return const Color(0xFFE76F51);
      case GemType.sapphire: return const Color(0xFF264653);
      case GemType.gold: return const Color(0xFFD4AF37);
    }
  }
  String get textIcon {
    switch (this) {
      case GemType.emerald: return '★';
      case GemType.amethyst: return '♦';
      case GemType.yellow: return '●';
      case GemType.ruby: return '≡';
      case GemType.sapphire: return '✖';
      case GemType.gold: return 'W';
    }
  }
  Gradient? get gradient {
    if (this == GemType.gold) {
      return const LinearGradient(colors: [Color(0xFFF1C40F), Color(0xFFB8860B)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
    return null;
  }
}

class MarketCard {
  final int id;
  final int tier;
  final int points; 
  final GemType provides;
  final Map<GemType, int> costs;

  const MarketCard({required this.id, required this.tier, required this.points, required this.provides, required this.costs});
}

class PlayerState {
  final String name;
  final String avatar;
  int score = 0;
  
  Map<GemType, int> engine = {
    GemType.emerald: 0, GemType.amethyst: 0, GemType.yellow: 0,
    GemType.ruby: 0, GemType.sapphire: 0
  };

  Map<GemType, int> wallet = {
    GemType.emerald: 0, GemType.amethyst: 0, GemType.yellow: 0,
    GemType.ruby: 0, GemType.sapphire: 0, GemType.gold: 0
  };
  
  List<MarketCard> reservedCards = [];

  PlayerState(this.name, this.avatar);
}


// --- MAIN SCREEN ---

class GemCrafterScreen extends StatefulWidget {
  const GemCrafterScreen({super.key});

  @override
  State<GemCrafterScreen> createState() => _GemCrafterScreenState();
}

class _GemCrafterScreenState extends State<GemCrafterScreen> {
  
  // STATE ENGINE
  late List<PlayerState> _players;
  int _turnIndex = 0;

  Map<GemType, int> _bank = {
    GemType.emerald: 5, GemType.amethyst: 5, GemType.yellow: 5,
    GemType.ruby: 5, GemType.sapphire: 3, GemType.gold: 5 // Sapphire starts at 3 for Unit Test
  };

  List<MarketCard> _market = [];
  
  // DRAFT & DISCARD STATE
  List<GemType> _draftSelection = [];
  bool _isDiscarding = false;

  @override
  void initState() {
    super.initState();
    _initializeTests();
  }

  void _initializeTests() {
    // Player 1 (Jahn)
    PlayerState p1 = PlayerState("Jahn", "J");
    p1.engine[GemType.ruby] = 2;
    p1.wallet[GemType.ruby] = 1;
    // Unit Test: 9 total tokens (Drafting forces Discard State)
    p1.wallet[GemType.emerald] = 3;
    p1.wallet[GemType.yellow] = 3;
    p1.wallet[GemType.amethyst] = 2; 

    // Player 2 (Bee)
    PlayerState p2 = PlayerState("Bee", "B");
    p2.wallet[GemType.gold] = 2; 
    // Unit Test: Max Reserved Cards
    p2.reservedCards = [
      const MarketCard(id: 101, tier: 1, points: 0, provides: GemType.emerald, costs: {}),
      const MarketCard(id: 102, tier: 1, points: 0, provides: GemType.ruby, costs: {}),
      const MarketCard(id: 103, tier: 2, points: 1, provides: GemType.sapphire, costs: {}),
    ];

    _players = [p1, p2];

    MarketCard testCard1 = const MarketCard(id: 1, tier: 1, points: 2, provides: GemType.sapphire, costs: {GemType.ruby: 3});
    MarketCard testCard2 = const MarketCard(id: 2, tier: 1, points: 0, provides: GemType.ruby, costs: {GemType.emerald: 2});

    _market = [
      testCard1, testCard2,
      const MarketCard(id: 3, tier: 1, points: 0, provides: GemType.emerald, costs: {GemType.sapphire: 1, GemType.amethyst: 2}),
      const MarketCard(id: 4, tier: 1, points: 0, provides: GemType.amethyst, costs: {GemType.yellow: 2, GemType.ruby: 2}),
      const MarketCard(id: 5, tier: 2, points: 2, provides: GemType.yellow, costs: {GemType.emerald: 4, GemType.sapphire: 2}),
      const MarketCard(id: 6, tier: 2, points: 1, provides: GemType.ruby, costs: {GemType.yellow: 3, GemType.amethyst: 2}),
      const MarketCard(id: 7, tier: 2, points: 2, provides: GemType.sapphire, costs: {GemType.ruby: 5}),
      const MarketCard(id: 8, tier: 2, points: 2, provides: GemType.amethyst, costs: {GemType.emerald: 4, GemType.ruby: 1}),
      const MarketCard(id: 9, tier: 3, points: 4, provides: GemType.sapphire, costs: {GemType.amethyst: 6, GemType.ruby: 3}),
      const MarketCard(id: 10, tier: 3, points: 5, provides: GemType.emerald, costs: {GemType.emerald: 7, GemType.yellow: 3}),
      const MarketCard(id: 11, tier: 3, points: 3, provides: GemType.amethyst, costs: {GemType.sapphire: 5, GemType.ruby: 3}),
      const MarketCard(id: 12, tier: 3, points: 4, provides: GemType.ruby, costs: {GemType.amethyst: 7}),
    ];
  }

  // --- CORE ENGINE LOGIC ---

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: const Color(0xFFE76F51),
      duration: const Duration(seconds: 2),
    ));
  }

  void _endTurnOrDiscard() {
    PlayerState player = _players[_turnIndex];
    int totalTokens = player.wallet.values.fold(0, (sum, val) => sum + val);
    
    setState(() {
      if (totalTokens > 10) {
        _isDiscarding = true;
      } else {
        _isDiscarding = false;
        _turnIndex = (_turnIndex + 1) % _players.length;
      }
    });
  }

  void _discardToken(GemType gem) {
    if (!_isDiscarding) return;
    PlayerState player = _players[_turnIndex];
    
    if ((player.wallet[gem] ?? 0) > 0) {
      setState(() {
        player.wallet[gem] = player.wallet[gem]! - 1;
        _bank[gem] = (_bank[gem] ?? 0) + 1;
      });
      _endTurnOrDiscard();
    }
  }

  void _handleBankTap(GemType gem) {
    if (_isDiscarding) return;
    if (gem == GemType.gold) {
      _showError("Gold tokens can only be acquired by reserving cards.");
      return;
    }
    if ((_bank[gem] ?? 0) <= 0) return;

    setState(() {
      if (_draftSelection.contains(gem)) {
        if (_draftSelection.length == 1) {
          if ((_bank[gem] ?? 0) >= 4) {
            _draftSelection.add(gem);
            _commitDraft();
          } else {
            _showError("Cannot take 2 tokens: Bank must have at least 4 remaining.");
            _draftSelection.clear();
          }
        } else {
          _showError("You cannot pick the same color again.");
        }
      } else {
        _draftSelection.add(gem);
        if (_draftSelection.length == 3) {
          _commitDraft();
        }
      }
    });
  }

  void _commitDraft() {
    PlayerState player = _players[_turnIndex];
    setState(() {
      for (var gem in _draftSelection) {
        player.wallet[gem] = (player.wallet[gem] ?? 0) + 1;
        _bank[gem] = (_bank[gem] ?? 0) - 1;
      }
      _draftSelection.clear();
    });
    _endTurnOrDiscard();
  }

  void _cancelDraft() {
    setState(() => _draftSelection.clear());
  }

  void _reserveCard(MarketCard card, {bool fromDeck = false}) {
    if (_isDiscarding) return;
    PlayerState player = _players[_turnIndex];
    
    if (player.reservedCards.length >= 3) {
      _showError("You cannot reserve more than 3 cards!");
      return;
    }

    setState(() {
      player.reservedCards.add(card);
      if ((_bank[GemType.gold] ?? 0) > 0) {
        player.wallet[GemType.gold] = (player.wallet[GemType.gold] ?? 0) + 1;
        _bank[GemType.gold] = _bank[GemType.gold]! - 1;
      }
      
      if (!fromDeck) {
        int idx = _market.indexOf(card);
        if (idx != -1) {
          // V66 BUGFIX: Strict Enum Mapping for random generation
          _market[idx] = MarketCard(
            id: math.Random().nextInt(1000), 
            tier: card.tier, 
            points: card.tier, 
            provides: GemType.values[math.Random().nextInt(5)], 
            costs: {GemType.values[math.Random().nextInt(5)]: card.tier + 1}
          );
        }
      }
    });
    _endTurnOrDiscard();
  }

  bool _canAfford(MarketCard card, PlayerState player) {
    int wildTokensNeeded = 0;
    card.costs.forEach((gemType, costRequired) {
      int deficit = costRequired - (player.engine[gemType] ?? 0);
      if (deficit > 0) {
        int remainingDeficit = deficit - (player.wallet[gemType] ?? 0);
        if (remainingDeficit > 0) wildTokensNeeded += remainingDeficit;
      }
    });
    return (player.wallet[GemType.gold] ?? 0) >= wildTokensNeeded;
  }

  void _purchaseCard(MarketCard card) {
    if (_isDiscarding) return;
    PlayerState player = _players[_turnIndex];
    if (!_canAfford(card, player)) return;

    int wildTokensUsed = 0;
    card.costs.forEach((gemType, costRequired) {
      int deficit = costRequired - (player.engine[gemType] ?? 0);
      if (deficit > 0) {
        int available = player.wallet[gemType] ?? 0;
        if (available >= deficit) {
          player.wallet[gemType] = available - deficit;
          _bank[gemType] = (_bank[gemType] ?? 0) + deficit;
        } else {
          player.wallet[gemType] = 0;
          _bank[gemType] = (_bank[gemType] ?? 0) + available;
          wildTokensUsed += (deficit - available);
        }
      }
    });

    if (wildTokensUsed > 0) {
      player.wallet[GemType.gold] = (player.wallet[GemType.gold] ?? 0) - wildTokensUsed;
      _bank[GemType.gold] = (_bank[GemType.gold] ?? 0) + wildTokensUsed;
    }

    player.engine[card.provides] = (player.engine[card.provides] ?? 0) + 1;
    player.score += card.points;

    int cardIndex = _market.indexOf(card);
    if (cardIndex != -1) {
      // V66 BUGFIX: Strict Enum Mapping for random generation
      _market[cardIndex] = MarketCard(
        id: math.Random().nextInt(1000), 
        tier: card.tier, 
        points: 0, 
        provides: GemType.values[math.Random().nextInt(5)], 
        costs: {GemType.values[math.Random().nextInt(5)]: 1}
      );
    }

    _endTurnOrDiscard();
  }

  // --- UI RENDER ---

  @override
  Widget build(BuildContext context) {
    PlayerState currentPlayer = _players[_turnIndex];
    List<PlayerState> opponents = _players.where((p) => p != currentPlayer).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSky(opponents, currentPlayer.name),
            IgnorePointer(
              ignoring: _isDiscarding,
              child: Opacity(
                opacity: _isDiscarding ? 0.5 : 1.0,
                child: Column(
                  children: [
                    _buildNobles(),
                    SizedBox(height: 240, child: _buildMarket(currentPlayer)),
                    _buildBank(),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildDashboard(currentPlayer)),
          ],
        ),
      ),
    );
  }

  Widget _buildSky(List<PlayerState> opponents, String currName) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isDiscarding ? const Color(0xFFE76F51) : const Color(0xFF2A9D8F), 
                  borderRadius: BorderRadius.circular(12), 
                  boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0,1), blurRadius: 2)]
                ),
                child: Text(
                  _isDiscarding ? "DISCARD TO 10 TOKENS" : "CURRENT TURN: ${currName.toUpperCase()}", 
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
              ),
              Text("GEM CRAFTER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: opponents.map((opp) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: OpponentCard(player: opp),
              )
            )).toList(),
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
          NobleTile(points: 3, req: {GemType.emerald: 4, GemType.amethyst: 4}),
          SizedBox(width: 8),
          NobleTile(points: 3, req: {GemType.ruby: 3, GemType.sapphire: 3, GemType.yellow: 3}),
          SizedBox(width: 8),
          NobleTile(points: 3, req: {GemType.amethyst: 4, GemType.sapphire: 4}),
        ],
      ),
    );
  }

  Widget _buildMarket(PlayerState currentPlayer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Expanded(child: DeckCard(tier: 3, count: 12, textColor: Colors.lightBlueAccent, onTap: () => _reserveCard(const MarketCard(id: 999, tier: 3, points: 3, provides: GemType.sapphire, costs: {}), fromDeck: true))),
                const SizedBox(height: 6),
                Expanded(child: DeckCard(tier: 2, count: 24, textColor: Colors.amberAccent, onTap: () => _reserveCard(const MarketCard(id: 998, tier: 2, points: 1, provides: GemType.emerald, costs: {}), fromDeck: true))),
                const SizedBox(height: 6),
                Expanded(child: DeckCard(tier: 1, count: 36, textColor: const Color(0xFF2A9D8F), onTap: () => _reserveCard(const MarketCard(id: 997, tier: 1, points: 0, provides: GemType.ruby, costs: {}), fromDeck: true))),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(child: Row(children: _market.sublist(8, 12).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6.0), child: MarketCardWidget(card: c, affordable: _canAfford(c, currentPlayer), onTap: () => _purchaseCard(c), onLongPress: () => _reserveCard(c))))).toList())),
                const SizedBox(height: 6),
                Expanded(child: Row(children: _market.sublist(4, 8).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6.0), child: MarketCardWidget(card: c, affordable: _canAfford(c, currentPlayer), onTap: () => _purchaseCard(c), onLongPress: () => _reserveCard(c))))).toList())),
                const SizedBox(height: 6),
                Expanded(child: Row(children: _market.sublist(0, 4).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6.0), child: MarketCardWidget(card: c, affordable: _canAfford(c, currentPlayer), onTap: () => _purchaseCard(c), onLongPress: () => _reserveCard(c))))).toList())),
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
      child: Column(
        children: [
          if (_draftSelection.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _cancelDraft,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(12)), child: const Text("CANCEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _commitDraft,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF2A9D8F), borderRadius: BorderRadius.circular(12)), child: const Text("CONFIRM", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  )
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: GemType.values.map((gem) {
              int selectedCount = _draftSelection.where((g) => g == gem).length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: BankToken(
                  gem: gem, 
                  count: _bank[gem]!, 
                  selectedCount: selectedCount,
                  onTap: () => _handleBankTap(gem)
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(PlayerState player) {
    Widget dashboard = Container(
      decoration: BoxDecoration(
        color: _isDiscarding ? const Color(0xFFF9F7F3) : Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: _isDiscarding ? Border.all(color: const Color(0xFFE76F51), width: 3) : null,
        boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, -4), blurRadius: 20)],
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
                  Text(player.score.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2A9D8F), height: 1)),
                ],
              ),
              Row(
                children: [
                  Text("RESERVED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 1.5)),
                  const SizedBox(width: 6),
                  ...List.generate(3, (i) {
                    bool filled = i < player.reservedCards.length;
                    return Container(
                      width: 20, height: 28, margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: filled ? player.reservedCards[i].provides.color : Colors.transparent,
                        borderRadius: BorderRadius.circular(4), 
                        border: Border.all(color: filled ? Colors.black26 : Colors.blueGrey[300]!)
                      )
                    );
                  })
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: EngineBlock(gem: GemType.emerald, count: player.engine[GemType.emerald]!)),
              const SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemType.amethyst, count: player.engine[GemType.amethyst]!)),
              const SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemType.yellow, count: player.engine[GemType.yellow]!)),
              const SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemType.ruby, count: player.engine[GemType.ruby]!)),
              const SizedBox(width: 6),
              Expanded(child: EngineBlock(gem: GemType.sapphire, count: player.engine[GemType.sapphire]!)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDiscarding ? const Color(0xFFE76F51).withOpacity(0.1) : const Color(0xFFF9F7F3), 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: _isDiscarding ? const Color(0xFFE76F51) : Colors.blueGrey[200]!)
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("TOKENS IN HAND", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isDiscarding ? const Color(0xFFE76F51) : Colors.blueGrey[400], letterSpacing: 1.5)),
                    Text("${player.wallet.values.fold(0, (sum, item) => sum + item)} / 10", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isDiscarding ? const Color(0xFFE76F51) : Colors.blueGrey[500])),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ..._buildWalletTokens(player),
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

    return dashboard;
  }

  List<Widget> _buildWalletTokens(PlayerState player) {
    List<Widget> tokens = [];
    bool first = true;
    for (var gem in GemType.values) {
      for (int i = 0; i < (player.wallet[gem] ?? 0); i++) {
        Widget token = GestureDetector(
          onTap: () => _discardToken(gem),
          child: WalletToken(gem: gem)
        );
        if (first) {
          tokens.add(token);
          first = false;
        } else {
          tokens.add(Align(widthFactor: 0.7, child: token));
        }
      }
    }
    return tokens;
  }
}

// --- WIDGET COMPONENTS ---

Widget _buildGemIcon(GemType gem, double size, {Color? color}) {
  return Text(
    gem.textIcon, 
    style: TextStyle(
      fontSize: size, 
      fontWeight: FontWeight.w900, 
      color: color ?? Colors.white, 
      height: 1.1,
      leadingDistribution: TextLeadingDistribution.even
    ),
    textAlign: TextAlign.center,
  );
}

class OpponentCard extends StatelessWidget {
  final PlayerState player;

  const OpponentCard({super.key, required this.player});

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
                  CircleAvatar(radius: 8, backgroundColor: const Color(0xFF2A9D8F), child: Text(player.avatar, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 4),
                  Text(player.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ],
              ),
              Text(player.score.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF2A9D8F))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ...[GemType.emerald, GemType.amethyst, GemType.yellow, GemType.ruby, GemType.sapphire].map((g) {
                int c = player.engine[g] ?? 0;
                return Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: g.color.withOpacity(c > 0 ? 1.0 : 0.2), borderRadius: BorderRadius.circular(2)),
                  child: Center(child: Text(c > 0 ? c.toString() : "", style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold))),
                );
              }),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: GemType.values.map((g) {
              int c = player.wallet[g] ?? 0;
              return Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: g.gradient == null ? g.color.withOpacity(c > 0 ? 1.0 : 0.2) : null,
                  gradient: g.gradient != null && c > 0 ? g.gradient : null,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(c > 0 ? c.toString() : "", style: const TextStyle(fontSize: 6, color: Colors.white, fontWeight: FontWeight.bold))),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class NobleTile extends StatelessWidget {
  final int points;
  final Map<GemType, int> req;
  const NobleTile({super.key, required this.points, required this.req});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: const Color(0xFFD4AF37), width: 2), 
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(points.toString(), style: const TextStyle(color: Color(0xFFB8860B), fontWeight: FontWeight.w900, fontSize: 16, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: req.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                children: [
                  Text(entry.value.toString(), style: const TextStyle(color: Color(0xFF2B2D42), fontSize: 8, fontWeight: FontWeight.w900, height: 1)),
                  Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 1), decoration: BoxDecoration(color: entry.key.color, borderRadius: BorderRadius.circular(1))),
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
  final VoidCallback onTap;
  const DeckCard({super.key, required this.tier, required this.count, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String numeral = tier == 3 ? "III" : (tier == 2 ? "II" : "I");
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueGrey[600]!), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 2)]),
        child: Stack(
          children: [
            Center(child: Text(numeral, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -2))),
            Positioned(bottom: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(2)), child: Text(count.toString(), style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }
}

class MarketCardWidget extends StatelessWidget {
  final MarketCard card;
  final bool affordable;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MarketCardWidget({super.key, required this.card, required this.affordable, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: affordable ? onTap : null,
      onLongPress: onLongPress,
      child: AnimatedOpacity(
        opacity: affordable ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: affordable ? Colors.blueGrey[300]! : Colors.blueGrey[100]!), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 2)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.points > 0 ? card.points.toString() : "", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey[700], height: 1)),
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(color: card.provides.color, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 1)]),
                    child: Center(child: _buildGemIcon(card.provides, 9, color: Colors.white)),
                  )
                ],
              ),
              Wrap(
                spacing: 2, runSpacing: 2,
                children: card.costs.entries.map((entry) => Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: entry.key.color, shape: BoxShape.circle),
                  child: Center(child: Text(entry.value.toString(), style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900))),
                )).toList(),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class BankToken extends StatelessWidget {
  final GemType gem;
  final int count;
  final int selectedCount;
  final VoidCallback onTap;

  const BankToken({super.key, required this.gem, required this.count, required this.selectedCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    bool empty = count == 0;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: empty ? 0.3 : 1.0,
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: gem.gradient == null ? gem.color : null, 
                gradient: gem.gradient, 
                shape: BoxShape.circle, 
                border: Border.all(color: selectedCount > 0 ? const Color(0xFFE76F51) : Colors.white, width: selectedCount > 0 ? 3 : 2), 
                boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]
              ),
              child: Center(child: _buildGemIcon(gem, 18, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.blueGrey[200], borderRadius: BorderRadius.circular(12)),
              child: Text(count.toString(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey[600], height: 1)),
            )
          ],
        ),
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
          if (active) Padding(padding: const EdgeInsets.only(top: 2), child: _buildGemIcon(gem, 10, color: Colors.white)),
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
      child: Center(child: _buildGemIcon(gem, 12, color: Colors.white)),
    );
  }
}