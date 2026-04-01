import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../../core/ui/physics_button.dart';

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
  IconData get iconData {
    switch (this) {
      case GemType.emerald: return Icons.star;
      case GemType.amethyst: return Icons.diamond;
      case GemType.yellow: return Icons.circle;
      case GemType.ruby: return Icons.menu;
      case GemType.sapphire: return Icons.close;
      case GemType.gold: return Icons.stars;
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

class NobleCard {
  final int id;
  final int points;
  final Map<GemType, int> requirements;
  const NobleCard({required this.id, required this.points, required this.requirements});
}

class PlayerState {
  final String name;
  final String avatar;
  final Color avatarColor;
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
  List<NobleCard> earnedNobles = []; // V20.1: Track earned nobles

  PlayerState(this.name, this.avatar, this.avatarColor);
}

// --- MAIN SCREEN ---

class GemCrafterScreen extends StatefulWidget {
  final List<String>? playerNames; 
  const GemCrafterScreen({super.key, this.playerNames});

  @override
  State<GemCrafterScreen> createState() => _GemCrafterScreenState();
}

class _GemCrafterScreenState extends State<GemCrafterScreen> {
  bool _isInitialized = false;
  bool _isFinalRound = false;
  bool _isGameOver = false;

  late List<PlayerState> _players;
  int _turnIndex = 0;

  late Map<GemType, int> _bank;

  List<MarketCard> _market = [];
  List<MarketCard> _deckTier1 = [];
  List<MarketCard> _deckTier2 = [];
  List<MarketCard> _deckTier3 = [];
  List<NobleCard> _availableNobles = [];
  
  List<GemType> _draftSelection = [];
  bool _isDiscarding = false;
  int _globalCardId = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      List<String>? finalNames;

      if (widget.playerNames != null && widget.playerNames!.isNotEmpty) {
        finalNames = widget.playerNames;
      } else {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is List) {
          finalNames = args.map((e) => e.toString()).toList();
        } else if (args is Map && args['players'] is List) {
          finalNames = (args['players'] as List).map((e) => e.toString()).toList();
        }
      }

      if (finalNames == null || finalNames.isEmpty) {
        finalNames = ["Player 1", "Player 2"];
      }

      _initializeGame(finalNames);
      _isInitialized = true;
    }
  }

  List<MarketCard> _generateDeck(int tier, List<Map<String, dynamic>> patterns) {
    List<MarketCard> deck = [];
    List<GemType> colors = [GemType.emerald, GemType.amethyst, GemType.yellow, GemType.ruby, GemType.sapphire];

    for (var p in patterns) {
      int points = p['points'];
      List<int> costs = List<int>.from(p['cost']);

      for (int i = 0; i < 5; i++) {
        GemType provides = colors[i];
        Map<GemType, int> costMap = {};
        for (int j = 0; j < costs.length; j++) {
          GemType costColor = colors[(i + j + 1) % 5];
          costMap[costColor] = costs[j];
        }
        deck.add(MarketCard(id: _globalCardId++, tier: tier, points: points, provides: provides, costs: costMap));
      }
    }
    return deck;
  }

  void _initializeGame(List<String> names) {
    List<Color> aColors = [const Color(0xFF2A9D8F), const Color(0xFF8E44AD), const Color(0xFFE9C46A), const Color(0xFFE76F51)];
    
    _players = [];
    for (int i = 0; i < names.length; i++) {
       _players.add(PlayerState(names[i], names[i].isNotEmpty ? names[i][0].toUpperCase() : "?", aColors[i % aColors.length]));
    }

    int tokenCount = names.length == 4 ? 7 : (names.length == 3 ? 5 : 4);
    _bank = {
      GemType.emerald: tokenCount,
      GemType.amethyst: tokenCount,
      GemType.yellow: tokenCount,
      GemType.ruby: tokenCount,
      GemType.sapphire: tokenCount,
      GemType.gold: 5,
    };

    _deckTier1 = _generateDeck(1, [
      {"points": 0, "cost": [1, 1, 1, 1]}, {"points": 0, "cost": [1, 2]}, {"points": 0, "cost": [2, 2]},
      {"points": 0, "cost": [1, 2, 2]}, {"points": 0, "cost": [1, 1, 2, 1]}, {"points": 0, "cost": [3]},
      {"points": 0, "cost": [2, 1]}, {"points": 1, "cost": [4]},
    ]);

    _deckTier2 = _generateDeck(2, [
      {"points": 1, "cost": [3, 2, 2]}, {"points": 1, "cost": [3, 3]}, {"points": 2, "cost": [5]},
      {"points": 2, "cost": [5, 3]}, {"points": 2, "cost": [4, 2, 1]}, {"points": 3, "cost": [6]},
    ]);

    _deckTier3 = _generateDeck(3, [
      {"points": 3, "cost": [3, 3, 3, 5]}, {"points": 4, "cost": [7]},
      {"points": 4, "cost": [6, 3, 3]}, {"points": 5, "cost": [7, 3]},
    ]);

    List<NobleCard> allNobles = [
      NobleCard(id: 1, points: 3, requirements: {GemType.yellow: 3, GemType.sapphire: 3, GemType.amethyst: 3}),
      NobleCard(id: 2, points: 3, requirements: {GemType.yellow: 3, GemType.ruby: 3, GemType.amethyst: 3}),
      NobleCard(id: 3, points: 3, requirements: {GemType.sapphire: 3, GemType.emerald: 3, GemType.ruby: 3}),
      NobleCard(id: 4, points: 3, requirements: {GemType.yellow: 3, GemType.sapphire: 3, GemType.emerald: 3}),
      NobleCard(id: 5, points: 3, requirements: {GemType.emerald: 3, GemType.ruby: 3, GemType.amethyst: 3}),
      NobleCard(id: 6, points: 3, requirements: {GemType.ruby: 4, GemType.amethyst: 4}),
      NobleCard(id: 7, points: 3, requirements: {GemType.emerald: 4, GemType.ruby: 4}),
      NobleCard(id: 8, points: 3, requirements: {GemType.yellow: 4, GemType.sapphire: 4}),
      NobleCard(id: 9, points: 3, requirements: {GemType.sapphire: 4, GemType.emerald: 4}),
      NobleCard(id: 10, points: 3, requirements: {GemType.yellow: 4, GemType.amethyst: 4}),
    ];

    allNobles.shuffle();
    _availableNobles = allNobles.take(_players.length + 1).toList();

    _deckTier1.shuffle();
    _deckTier2.shuffle();
    _deckTier3.shuffle();

    _market = [
      _drawCard(1), _drawCard(1), _drawCard(1), _drawCard(1), 
      _drawCard(2), _drawCard(2), _drawCard(2), _drawCard(2), 
      _drawCard(3), _drawCard(3), _drawCard(3), _drawCard(3), 
    ];
  }

  MarketCard _drawCard(int tier) {
    if (tier == 1 && _deckTier1.isNotEmpty) return _deckTier1.removeLast();
    if (tier == 2 && _deckTier2.isNotEmpty) return _deckTier2.removeLast();
    if (tier == 3 && _deckTier3.isNotEmpty) return _deckTier3.removeLast();
    return MarketCard(id: -1, tier: tier, points: 0, provides: GemType.emerald, costs: {}); 
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
    
    NobleCard? claimedNoble;
    for (var noble in _availableNobles) {
      bool meetsReqs = true;
      noble.requirements.forEach((gem, count) {
        if ((player.engine[gem] ?? 0) < count) meetsReqs = false;
      });
      if (meetsReqs) {
        claimedNoble = noble;
        break; 
      }
    }

    if (claimedNoble != null) {
      setState(() {
        player.score += claimedNoble!.points;
        player.earnedNobles.add(claimedNoble!);
        _availableNobles.remove(claimedNoble);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${player.name} claimed a Noble!", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFD4AF37),
        duration: const Duration(seconds: 3),
      ));
    }

    // Trigger Final Round if 15 points reached
    if (player.score >= 15) {
      _isFinalRound = true;
    }

    int totalTokens = player.wallet.values.fold(0, (sum, val) => sum + val);
    
    setState(() {
      if (totalTokens > 10) {
        _isDiscarding = true;
      } else {
        _isDiscarding = false;
        // If it's the final round AND the last player just finished their turn
        if (_isFinalRound && _turnIndex == _players.length - 1) {
          _isGameOver = true;
        } else {
          _turnIndex = (_turnIndex + 1) % _players.length;
        }
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

  void _reserveFromBoard(MarketCard card) {
    _executeReservation(card);
    int idx = _market.indexOf(card);
    if (idx != -1) {
      setState(() => _market[idx] = _drawCard(card.tier));
    }
  }

  void _reserveFromDeck(int tier) {
    MarketCard card = _drawCard(tier);
    if (card.id != -1) {
      _executeReservation(card);
    }
  }

  void _executeReservation(MarketCard card) {
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

  void _executePurchaseTransaction(MarketCard card, PlayerState player) {
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
  }

  void _purchaseCard(MarketCard card) {
    if (_isDiscarding) return;
    PlayerState player = _players[_turnIndex];
    if (!_canAfford(card, player)) return;

    setState(() {
      _executePurchaseTransaction(card, player);
      int cardIndex = _market.indexOf(card);
      if (cardIndex != -1) {
        _market[cardIndex] = _drawCard(card.tier);
      }
    });
    _endTurnOrDiscard();
  }

  void _purchaseReservedCard(MarketCard card) {
    if (_isDiscarding) return;
    PlayerState player = _players[_turnIndex];
    if (!_canAfford(card, player)) return;

    setState(() {
      _executePurchaseTransaction(card, player);
      player.reservedCards.remove(card);
    });
    _endTurnOrDiscard();
  }

  void _showReservedCardModal(MarketCard card) {
    bool affordable = _canAfford(card, _players[_turnIndex]);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFFF9F7F3), borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("RESERVED CARD", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 2)),
              const SizedBox(height: 24),
              SizedBox(
                width: 140, height: 180, 
                child: MarketCardWidget(card: card, affordable: true, onTap: (){}, onLongPress: (){})
              ),
              const SizedBox(height: 24),
              if (affordable)
                PhysicsButton(
                  text: "BUY CARD",
                  color: const Color(0xFF2A9D8F),
                  shadowColor: const Color(0xFF1E7066),
                  onTap: () {
                    Navigator.pop(ctx);
                    _purchaseReservedCard(card);
                  }
                )
              else
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text("CANNOT AFFORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)))
                ),
              const SizedBox(height: 12),
              PhysicsButton(
                text: "CLOSE", 
                color: const Color(0xFFE76F51), 
                shadowColor: const Color(0xFFB3563F), 
                onTap: () => Navigator.pop(ctx)
              )
            ]
          )
        )
      )
    );
  }

  // --- UI RENDER ---

  Widget _buildVictoryModal() {
    List<PlayerState> ranked = List.from(_players);
    ranked.sort((a, b) {
      int cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      int aCards = a.engine.values.fold(0, (s,v)=>s+v);
      int bCards = b.engine.values.fold(0, (s,v)=>s+v);
      return aCards.compareTo(bCards);
    });

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 64, color: Color(0xFFD4AF37)),
                  const SizedBox(height: 16),
                  const Text("MATCH COMPLETE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF2B2D42))),
                  const SizedBox(height: 32),
                  ...ranked.map((p) {
                    bool isWinner = p == ranked.first;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(radius: 12, backgroundColor: p.avatarColor, child: Text(p.avatar, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              Text(p.name, style: TextStyle(fontSize: 14, fontWeight: isWinner ? FontWeight.w900 : FontWeight.bold, color: const Color(0xFF2B2D42))),
                            ]
                          ),
                          Text(p.score.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isWinner ? const Color(0xFF2A9D8F) : const Color(0xFF2B2D42))),
                        ]
                      )
                    );
                  }).toList(),
                  const SizedBox(height: 48),
                  PhysicsButton(text: "EXIT TO LOBBY", color: const Color(0xFFE76F51), shadowColor: const Color(0xFFB3563F), onTap: () => Navigator.pop(context)),
                ]
              )
            )
          )
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(backgroundColor: Color(0xFFF9F7F3));

    PlayerState currentPlayer = _players[_turnIndex];
    List<PlayerState> opponents = _players.where((p) => p != currentPlayer).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
            if (_isGameOver) _buildVictoryModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildSky(List<PlayerState> opponents, String currName) {
    String statusText = _isDiscarding ? "DISCARD TO 10 TOKENS" : (_isFinalRound ? "FINAL ROUND: ${currName.toUpperCase()}" : "CURRENT TURN: ${currName.toUpperCase()}");
    Color statusColor = _isDiscarding ? const Color(0xFFE76F51) : (_isFinalRound ? const Color(0xFFE9C46A) : const Color(0xFF2A9D8F));

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
                  color: statusColor, 
                  borderRadius: BorderRadius.circular(12), 
                  boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0,1), blurRadius: 2)]
                ),
                child: Text(
                  statusText, 
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
              ),
              Text("GEM CRAFTER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: opponents.map((opp) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: OpponentCard(player: opp, opponentCount: opponents.length),
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
        children: _availableNobles.map((noble) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: NobleTile(noble: noble),
          );
        }).toList(),
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
                Expanded(child: DeckCard(tier: 3, count: _deckTier3.length, textColor: Colors.lightBlueAccent, onTap: () => _reserveFromDeck(3))),
                const SizedBox(height: 6),
                Expanded(child: DeckCard(tier: 2, count: _deckTier2.length, textColor: Colors.amberAccent, onTap: () => _reserveFromDeck(2))),
                const SizedBox(height: 6),
                Expanded(child: DeckCard(tier: 1, count: _deckTier1.length, textColor: const Color(0xFF2A9D8F), onTap: () => _reserveFromDeck(1))),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(child: Row(children: _market.sublist(8, 12).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6.0), child: c.id == -1 ? const SizedBox.shrink() : MarketCardWidget(card: c, affordable: _canAfford(c, currentPlayer), onTap: () => _purchaseCard(c), onLongPress: () => _reserveFromBoard(c))))).toList())),
                const SizedBox(height: 6),
                Expanded(child: Row(children: _market.sublist(4, 8).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6.0), child: c.id == -1 ? const SizedBox.shrink() : MarketCardWidget(card: c, affordable: _canAfford(c, currentPlayer), onTap: () => _purchaseCard(c), onLongPress: () => _reserveFromBoard(c))))).toList())),
                const SizedBox(height: 6),
                Expanded(child: Row(children: _market.sublist(0, 4).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6.0), child: c.id == -1 ? const SizedBox.shrink() : MarketCardWidget(card: c, affordable: _canAfford(c, currentPlayer), onTap: () => _purchaseCard(c), onLongPress: () => _reserveFromBoard(c))))).toList())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBank() {
    bool hasSelection = _draftSelection.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
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
          const SizedBox(height: 12),
          Opacity(
            opacity: hasSelection ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !hasSelection,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _cancelDraft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
                      decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(16)), 
                      child: const Text("CANCEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey))
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _commitDraft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
                      decoration: BoxDecoration(color: const Color(0xFF2A9D8F), borderRadius: BorderRadius.circular(16)), 
                      child: const Text("CONFIRM", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))
                    ),
                  )
                ],
              ),
            ),
          )
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("NOBLES EARNED", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber[600], letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(2, (i) {
                          bool earned = i < player.earnedNobles.length;
                          return Container(
                            width: 20, height: 26, margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: earned ? const Color(0xFFFDFBF7) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: earned ? const Color(0xFFD4AF37) : Colors.blueGrey[200]!)
                            ),
                            child: earned ? const Icon(Icons.workspace_premium, size: 14, color: Color(0xFFD4AF37)) : null
                          );
                        })
                      )
                    ]
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("RESERVED CARDS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(3, (i) {
                          bool filled = i < player.reservedCards.length;
                          return GestureDetector(
                            onTap: () {
                              if (filled) _showReservedCardModal(player.reservedCards[i]);
                            },
                            child: Container(
                              width: 18, height: 26, margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: filled ? player.reservedCards[i].provides.color : Colors.transparent,
                                borderRadius: BorderRadius.circular(4), 
                                border: Border.all(color: filled ? Colors.black26 : Colors.blueGrey[300]!)
                              )
                            ),
                          );
                        })
                      )
                    ]
                  )
                ]
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
  if (gem == GemType.gold) {
    return Text('W', style: TextStyle(fontSize: size * 1.1, fontWeight: FontWeight.w900, color: color ?? Colors.white, height: 1.1));
  }
  return Icon(gem.iconData, size: size * 1.2, color: color ?? Colors.white);
}

class OpponentCard extends StatelessWidget {
  final PlayerState player;
  final int opponentCount; 

  const OpponentCard({super.key, required this.player, required this.opponentCount});

  @override
  Widget build(BuildContext context) {
    bool compact = opponentCount >= 3;
    double avatarRadius = compact ? 8 : 10;
    double nameSize = compact ? 10 : 12;
    double scoreSize = compact ? 12 : 14;
    double paddingH = compact ? 6 : 10;
    double paddingV = compact ? 6 : 8;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: Colors.blueGrey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(radius: avatarRadius, backgroundColor: player.avatarColor, child: Text(player.avatar, style: TextStyle(fontSize: avatarRadius, color: Colors.white, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 4),
                    Expanded(child: Text(player.name, style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.bold, letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              Row(
                children: [
                  if (player.earnedNobles.isNotEmpty) ...[
                    Icon(Icons.workspace_premium, size: scoreSize * 0.9, color: const Color(0xFFD4AF37)),
                    Text(player.earnedNobles.length.toString(), style: TextStyle(fontSize: scoreSize * 0.8, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37))),
                    const SizedBox(width: 4),
                  ],
                  Text(player.score.toString(), style: TextStyle(fontSize: scoreSize, fontWeight: FontWeight.w900, color: const Color(0xFF2A9D8F))),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: GemType.values.map((g) {
                if (g == GemType.gold) return const SizedBox(width: 14);
                int c = player.engine[g] ?? 0;
                return Container(
                  width: 14, height: 14, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: c > 0 ? g.color : g.color.withOpacity(0.2), 
                    borderRadius: BorderRadius.circular(3),
                    border: c > 0 ? Border.all(color: Colors.black12) : null
                  ),
                  child: Center(child: Text(c > 0 ? c.toString() : "", style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: GemType.values.map((g) {
                int c = player.wallet[g] ?? 0;
                return Container(
                  width: 14, height: 14, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: g.gradient == null ? g.color.withOpacity(c > 0 ? 1.0 : 0.15) : null,
                    gradient: g.gradient != null && c > 0 ? g.gradient : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(c > 0 ? c.toString() : "", style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class NobleTile extends StatelessWidget {
  final NobleCard noble;
  const NobleTile({super.key, required this.noble});

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
          Text(noble.points.toString(), style: const TextStyle(color: Color(0xFFB8860B), fontWeight: FontWeight.w900, fontSize: 16, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: noble.requirements.entries.map((entry) => Padding(
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
      onTap: count > 0 ? onTap : null,
      child: AnimatedOpacity(
        opacity: count > 0 ? 1.0 : 0.2,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueGrey[600]!), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 2)]),
          child: Stack(
            children: [
              Center(child: Text(numeral, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -2))),
              Positioned(bottom: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(2)), child: Text(count.toString(), style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold)))),
            ],
          ),
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
                    child: Center(child: _buildGemIcon(card.provides, 8, color: Colors.white)),
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
                boxShadow: empty ? [] : const [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]
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
        color: active ? gem.color : gem.color.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: const Border(bottom: BorderSide(color: Colors.black26, width: 3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.white.withOpacity(0.7), height: 1)),
          Padding(padding: const EdgeInsets.only(top: 2), child: _buildGemIcon(gem, 10, color: active ? Colors.white : Colors.white.withOpacity(0.7))),
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