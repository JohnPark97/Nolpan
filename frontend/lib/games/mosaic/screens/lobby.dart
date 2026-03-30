import 'dart:async';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../core/ui/physics_button.dart';
import 'game.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _isJoined = false;
  String _roomCode = "";
  List<String> _players = [];
  String _selectedGame = "mosaic";

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    socketService.connect('wss://nolpan.onrender.com/ws');
    _codeCtrl.addListener(() { setState(() {}); });

    _sub = socketService.stream.listen((msg) {
      if (msg['type'] == 'ROOM_UPDATE') {
        if (mounted) {
          setState(() {
            _isJoined = true;
            _roomCode = msg['payload']['code'] ?? "";
            List dynPlayers = msg['payload']['players'] ?? [];
            _players = dynPlayers.map((e) => e.toString()).toList();
            _selectedGame = msg['payload']['game'] ?? 'mosaic';
          });
        }
      } else if (msg['type'] == 'GAME_STARTED') {
        if (mounted) {
          _sub.cancel();
          if (_selectedGame == 'mosaic') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(roomCode: _roomCode, initialState: msg['payload'])));
          } else {
            Navigator.pushReplacementNamed(context, '/merchant');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _handleConnect() {
    FocusScope.of(context).unfocus();
    String name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    
    socketService.playerName = name;
    String code = _codeCtrl.text.trim().toUpperCase();

    setState(() {
      _isJoined = true;
      if (code.isNotEmpty) {
        _roomCode = code;
      } else {
        _roomCode = "BOOTING...";
      }
      _players = [name];
    });
    
    if (code.isEmpty) {
      socketService.send('CREATE_ROOM', {'name': name});
    } else {
      socketService.send('JOIN_ROOM', {'name': name, 'code': code});
    }
  }

  void _changeGame(String gameType) {
    if (_players.isNotEmpty && _players.first == socketService.playerName) {
      socketService.send('CHANGE_GAME', {'code': _roomCode, 'game': gameType});
      setState(() => _selectedGame = gameType);
    }
  }

  void _startGame() {
    if (_players.isNotEmpty && _players.first == socketService.playerName && _players.length >= 2) {
      socketService.send('START_GAME', {'code': _roomCode});
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.blueGrey, size: 16),
                SizedBox(width: 4),
                Text("BACK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.5))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEntryState() {
    String dynamicButtonText = _codeCtrl.text.trim().isEmpty ? "CREATE ROOM" : "JOIN ROOM";

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24), 
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("NETWORK SETUP", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: tInk)),
            const SizedBox(height: 32),
            
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tInk),
              decoration: InputDecoration(
                hintText: "Your Name",
                hintStyle: TextStyle(color: Colors.blueGrey[300]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueGrey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueGrey[200]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: tTeal, width: 2)),
              ),
            ),
            
            const SizedBox(height: 12),
            
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tInk),
              decoration: InputDecoration(
                hintText: "Room Code (Optional)",
                hintStyle: TextStyle(color: Colors.blueGrey[300]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueGrey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueGrey[200]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: tTeal, width: 2)),
              ),
            ),

            const SizedBox(height: 32),
            PhysicsButton(
              text: dynamicButtonText, 
              color: tTeal, 
              shadowColor: const Color(0xFF1E7066),
              onTap: _handleConnect
            )
          ],
        )
      )
    );
  }

  Widget _buildMiniatureMosaic() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: const BoxDecoration(color: tTeal, shape: BoxShape.circle)),
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.blueGrey[100], shape: BoxShape.circle)),
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.blueGrey[100], shape: BoxShape.circle)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.blueGrey[100], shape: BoxShape.circle)),
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: const BoxDecoration(color: tGold, shape: BoxShape.circle)),
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.blueGrey[100], shape: BoxShape.circle)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.blueGrey[100], shape: BoxShape.circle)),
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.blueGrey[100], shape: BoxShape.circle)),
          Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: const BoxDecoration(color: tTerra, shape: BoxShape.circle)),
        ]),
      ],
    );
  }

  Widget _buildMiniatureMerchant() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => Container(
        width: 10, height: 20, 
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: Colors.blueGrey[300], borderRadius: BorderRadius.circular(4))
      )),
    );
  }

  Widget _buildWaitingRoomState() {
    bool isHost = _players.isNotEmpty && _players.first == socketService.playerName;
    bool canStart = _players.length >= 2;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24), 
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ONLINE LOBBY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("ROOM CODE: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.5)),
                Text(_roomCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: tTeal, letterSpacing: 3)),
              ],
            ),
            const SizedBox(height: 32),

            const Align(alignment: Alignment.centerLeft, child: Text("SELECT EXPERIENCE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.5))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _changeGame('mosaic'),
                    child: AnimatedContainer(
                      height: 100,
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedGame == 'mosaic' ? Colors.white : Colors.blueGrey[50]!.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _selectedGame == 'mosaic' ? tTeal : Colors.transparent, width: 2),
                        boxShadow: _selectedGame == 'mosaic' ? [const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))] : []
                      ),
                      child: Column(
                        children: [
                          Text("MOSAIC DRAFT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _selectedGame == 'mosaic' ? tTeal : Colors.blueGrey[300], letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Expanded(child: Center(child: _buildMiniatureMosaic())),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _changeGame('merchant'),
                    child: AnimatedContainer(
                      height: 100,
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedGame == 'merchant' ? Colors.white : Colors.blueGrey[50]!.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _selectedGame == 'merchant' ? const Color(0xFF8E44AD) : Colors.transparent, width: 2),
                        boxShadow: _selectedGame == 'merchant' ? [const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))] : []
                      ),
                      child: Column(
                        children: [
                          Text("GEM CRAFTER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _selectedGame == 'merchant' ? const Color(0xFF8E44AD) : Colors.blueGrey[300], letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Expanded(child: Center(child: _buildMiniatureMerchant())),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  if (i < _players.length) {
                    bool isLocal = _players[i] == socketService.playerName;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(radius: 20, backgroundColor: tTeal, child: Text(_players[i][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              if (isLocal) Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(_players[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tInk))
                        ],
                      ),
                    );
                  } else if (i == _players.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueGrey[200]!, style: BorderStyle.solid, width: 2)), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueGrey[200])))),
                        ],
                      ),
                    );
                  } else {
                    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(children: [Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueGrey[100]!.withOpacity(0.5)))]));
                  }
                }),
              ),
            ),
            const SizedBox(height: 32),

            if (isHost)
              PhysicsButton(
                text: "START GAME", 
                color: _selectedGame == 'mosaic' ? tTeal : const Color(0xFF8E44AD), 
                shadowColor: _selectedGame == 'mosaic' ? const Color(0xFF1E7066) : const Color(0xFF5E2B73),
                onTap: () { if (canStart) _startGame(); }
              )
            else
              Container(
                height: 60,
                decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueGrey[400])),
                      const SizedBox(width: 12),
                      Text("Waiting for Host to start...", style: TextStyle(color: Colors.blueGrey[500], fontWeight: FontWeight.bold, fontSize: 12))
                    ],
                  ),
                ),
              )
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        child: Stack(
          children: [
            if (!_isJoined) _buildTopBar(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child)),
              child: _isJoined ? _buildWaitingRoomState() : _buildEntryState()
            ),
          ],
        ),
      ),
    );
  }
}