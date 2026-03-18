import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import 'tournament_stats_screen.dart';

class TournamentVisualFixtureScreen extends StatefulWidget {
  final String clubId;
  final String tournamentId;
  final String tournamentName;
  final int playerCount;

  const TournamentVisualFixtureScreen({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.tournamentName,
    required this.playerCount,
  });

  @override
  State<TournamentVisualFixtureScreen> createState() => _TournamentVisualFixtureScreenState();
}

class _TournamentVisualFixtureScreenState extends State<TournamentVisualFixtureScreen> {
  final DatabaseService _db = DatabaseService();
  Map<int, Map<String, dynamic>> _slots = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('temp_layout')
          .doc('current')
          .get();
      
      if (doc.exists && doc.data()!['slots'] != null) {
        final Map<String, dynamic> loadedSlots = doc.data()!['slots'];
        setState(() {
          _slots = loadedSlots.map((k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading layout: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _persistLayout() async {
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('temp_layout')
        .doc('current')
        .set({'slots': _slots.map((k, v) => MapEntry(k.toString(), v))});
  }

  void _onPlayerWinner(int index, int nextIndex, List<String> score) async {
    setState(() {
      _slots[index]!['winner'] = true;
      _slots[index]!['isPlayed'] = true;
      _slots[index]!['locked'] = true;
      _slots[index]!['score'] = score;
      
      // El perdedor también se bloquea
      int opponentIndex = (index % 2 == 0) ? index + 1 : index - 1;
      if (_slots[opponentIndex] != null) {
        _slots[opponentIndex]!['isPlayed'] = true;
        _slots[opponentIndex]!['locked'] = true;
        _slots[opponentIndex]!['winner'] = false;
        _slots[opponentIndex]!['score'] = score;
      }

      // El ganador viaja al siguiente slot
      _slots[nextIndex] = Map<String, dynamic>.from(_slots[index]!);
      _slots[nextIndex]!['isPlayed'] = false;
      _slots[nextIndex]!['locked'] = false;
      _slots[nextIndex]!.remove('winner');
      _slots[nextIndex]!.remove('score');
    });

    await _persistLayout();
    
    // Guardar estadísticas en Firestore
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('match_stats')
        .add({
          'p1': _slots[index]!['name'],
          'p2': _slots[(index % 2 == 0) ? index + 1 : index - 1]?['name'] ?? 'BYE',
          'score': score,
          'winner': _slots[index]!['name'],
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  void _swapPlayers(int fromIndex, int toIndex) {
    if (_slots[fromIndex]?['locked'] == true || _slots[toIndex]?['locked'] == true) return;
    setState(() {
      final pFrom = _slots[fromIndex];
      final pTo = _slots[toIndex];
      if (pFrom != null) _slots[toIndex] = pFrom;
      if (pTo != null) _slots[fromIndex] = pTo; else _slots.remove(fromIndex);
    });
    _persistLayout();
  }

  void _showScoreModal(int p1, int p2, int nextIdx) {
    final s1p1 = TextEditingController(); final s1p2 = TextEditingController();
    final s2p1 = TextEditingController(); final s2p2 = TextEditingController();
    final s3p1 = TextEditingController(); final s3p2 = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text('Anotar Resultado', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSetRow('Set 1', s1p1, s1p2),
              _buildSetRow('Set 2', s2p1, s2p2),
              _buildSetRow('Set 3', s3p1, s3p2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00)),
            onPressed: () {
              int setsP1 = 0; int setsP2 = 0;
              List<String> score = [];
              
              void checkSet(TextEditingController c1, TextEditingController c2) {
                int j1 = int.tryParse(c1.text) ?? 0;
                int j2 = int.tryParse(c2.text) ?? 0;
                if (j1 > j2) setsP1++; else if (j2 > j1) setsP2++;
                if (j1 > 0 || j2 > 0) score.add('$j1-$j2');
              }

              checkSet(s1p1, s1p2);
              checkSet(s2p1, s2p2);
              if (setsP1 == setsP2) checkSet(s3p1, s3p2);

              if (setsP1 != setsP2) {
                _onPlayerWinner(setsP1 > setsP2 ? p1 : p2, nextIdx, score);
                Navigator.pop(context);
              }
            },
            child: const Text('FIJAR RESULTADO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(String label, TextEditingController c1, TextEditingController c2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(child: TextField(controller: c1, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('-', style: TextStyle(color: Colors.white))),
          Expanded(child: TextField(controller: c2, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00))));

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: Text(widget.tournamentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics, color: Color(0xFFCCFF00)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentStatsScreen(tournamentId: widget.tournamentId))),
            tooltip: 'Estadísticas',
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildBracketColumns(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBracketColumns() {
    List<Widget> columns = [];
    int currentSize = widget.playerCount;
    int offset = 0;
    int nextOffset = currentSize;

    List<String> roundNames = ['OCTAVOS', 'CUARTOS', 'SEMIS', 'FINAL'];
    int roundIdx = 0;
    if (currentSize == 8) roundIdx = 1;
    if (currentSize == 4) roundIdx = 2;

    while (currentSize >= 2) {
      columns.add(_buildRoundColumn(roundNames[roundIdx] ?? 'RONDA', currentSize, offset, nextOffset));
      if (currentSize > 2) columns.add(_buildConnectors(currentSize));
      
      offset = nextOffset;
      currentSize = currentSize ~/ 2;
      nextOffset = offset + currentSize;
      roundIdx++;
    }
    return columns;
  }

  Widget _buildRoundColumn(String title, int count, int offset, int nextOffset) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 30),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(count ~/ 2, (i) {
            int p1 = offset + (i * 2);
            int p2 = offset + (i * 2) + 1;
            int next = nextOffset + i;
            return Container(
              margin: EdgeInsets.symmetric(vertical: offset == 0 ? 10 : 30.0 * (offset / 4)),
              child: Column(
                children: [
                  _buildSlot(p1, offset == 0),
                  _buildVS(p1, p2, next),
                  _buildSlot(p2, offset == 0),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSlot(int index, bool canAddManual) {
    final p = _slots[index];
    bool isLocked = p?['locked'] ?? false;

    return DragTarget<int>(
      onWillAccept: (data) => !isLocked && canAddManual,
      onAccept: (fromIndex) => _swapPlayers(fromIndex, index),
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 150, height: 50,
          decoration: BoxDecoration(
            color: p != null ? (p['winner'] == true ? const Color(0xFFCCFF00).withOpacity(0.15) : const Color(0xFF2C4A44)) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p != null && p['winner'] == true ? const Color(0xFFCCFF00) : Colors.white12),
          ),
          child: p == null 
            ? (canAddManual ? InkWell(onTap: () => _showAddDialog(index), child: const Icon(Icons.add, size: 18, color: Colors.white24)) : const Center(child: Text('Esperando Ganador', style: TextStyle(color: Colors.white24, fontSize: 9))))
            : (isLocked ? _buildPlayerItem(index, p, false) : LongPressDraggable<int>(
                data: index,
                feedback: _buildPlayerItem(index, p, true),
                childWhenDragging: Opacity(opacity: 0.3, child: _buildPlayerItem(index, p, false)),
                child: _buildPlayerItem(index, p, false),
              )),
        );
      },
    );
  }

  Widget _buildPlayerItem(int index, Map<String, dynamic> p, bool isDragging) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 150, padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (p['winner'] == true) const Icon(Icons.emoji_events, color: Color(0xFFCCFF00), size: 14),
            const SizedBox(width: 5),
            Expanded(child: Text(p['name'] ?? '', style: TextStyle(color: isDragging ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (!isDragging && p['locked'] != true) IconButton(icon: const Icon(Icons.clear, size: 14, color: Colors.white24), onPressed: () {
              setState(() => _slots.remove(index));
              _persistLayout();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVS(int p1, int p2, int next) {
    bool ready = _slots[p1] != null && _slots[p2] != null;
    bool locked = (_slots[p1]?['locked'] == true) || (_slots[p2]?['locked'] == true);

    return InkWell(
      onTap: (ready && !locked) ? () => _showScoreModal(p1, p2, next) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(locked ? 'FINALIZADO' : 'ANOTAR', style: TextStyle(color: ready ? const Color(0xFFCCFF00) : Colors.white10, fontWeight: FontWeight.bold, fontSize: 9)),
      ),
    );
  }

  Widget _buildConnectors(int count) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(count ~/ 2, (i) => Container(width: 20, height: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(vertical: 60))),
    );
  }

  void _showAddDialog(int index) {
    final nameC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text('Registrar Jugador', style: TextStyle(color: Colors.white)),
        content: TextField(controller: nameC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nombre y Apellido')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () {
            setState(() => _slots[index] = {'name': nameC.text, 'locked': false});
            Navigator.pop(context);
            _persistLayout();
          }, child: const Text('GUARDAR')),
        ],
      ),
    );
  }
}
