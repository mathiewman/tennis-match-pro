import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../models/player_model.dart';
import '../models/tournament_model.dart';

class TournamentManualManagement extends StatefulWidget {
  final String clubId;
  const TournamentManualManagement({super.key, required this.clubId});

  @override
  State<TournamentManualManagement> createState() => _TournamentManualManagementState();
}

class _TournamentManualManagementState extends State<TournamentManualManagement> {
  final DatabaseService _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isSavingPlayer = false;
  bool _isAuthorized = false;
  bool _isLoadingAuth = true;
  bool _isManualSyncFinished = false;

  String? _selectedP1;
  String? _selectedP2;
  String _round = 'Octavos';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _checkSyncStatus();
  }

  Future<void> _checkPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'];
    if (mounted) {
      if (role == 'admin' || role == 'coordinator') {
        setState(() {
          _isAuthorized = true;
          _isLoadingAuth = false;
        });
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acceso Denegado: Solo coordinadores autorizados.')),
        );
      }
    }
  }

  Future<void> _checkSyncStatus() async {
    final doc = await FirebaseFirestore.instance.collection('tournaments').doc('manual_torneo_${widget.clubId}').get();
    if (doc.exists) {
      setState(() {
        _isManualSyncFinished = doc.data()?['isManualSyncFinished'] ?? false;
      });
    }
  }

  Future<void> _addManualPlayer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSavingPlayer = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final players = [{
        'name': '${_firstNameController.text} ${_lastNameController.text}',
        'phone': _phoneController.text,
        'category': 'Torneo Actual',
        'availability': {},
      }];

      await _dbService.bulkAddTournamentPlayers(user!.uid, widget.clubId, players);
      
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jugador agregado con éxito')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSavingPlayer = false);
    }
  }

  Future<void> _createMatch(String? p1, String? p2, String round) async {
    if (p1 == null || p2 == null || p1 == p2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona dos jugadores diferentes.')));
      return;
    }

    final match = TournamentMatch(
      id: '',
      tournamentId: 'manual_torneo_${widget.clubId}',
      player1Id: p1,
      player2Id: p2,
      score: [],
      round: round,
      status: 'pending',
      isManualSync: true,
    );

    try {
      await _dbService.saveTournamentMatch(match);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cruce creado con éxito')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _finalizeSync() async {
    await FirebaseFirestore.instance.collection('tournaments').doc('manual_torneo_${widget.clubId}').set({
      'isManualSyncFinished': true,
    }, SetOptions(merge: true));
    setState(() => _isManualSyncFinished = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronización finalizada.')));
    }
  }

  void _showScoreModal(TournamentMatch match) {
    final s1p1 = TextEditingController();
    final s1p2 = TextEditingController();
    final s2p1 = TextEditingController();
    final s2p2 = TextEditingController();
    final s3p1 = TextEditingController();
    final s3p2 = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text('Anotador de Tenis', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSetInput('Set 1', s1p1, s1p2),
              _buildSetInput('Set 2', s2p1, s2p2),
              _buildSetInput('Set 3', s3p1, s3p2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00)),
            onPressed: () => _saveMatchResult(match, [s1p1.text, s1p2.text, s2p1.text, s2p2.text, s3p1.text, s3p2.text]),
            child: const Text('GUARDAR', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildSetInput(String label, TextEditingController c1, TextEditingController c2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(child: TextField(controller: c1, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'J1', hintStyle: TextStyle(color: Colors.white30)))),
              const SizedBox(width: 20),
              const Text('-', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 20),
              Expanded(child: TextField(controller: c2, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'J2', hintStyle: TextStyle(color: Colors.white30)))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveMatchResult(TournamentMatch match, List<String> rawScores) async {
    int setsP1 = 0;
    int setsP2 = 0;
    List<String> finalScore = [];

    for (int i = 0; i < rawScores.length; i += 2) {
      int j1 = int.tryParse(rawScores[i]) ?? 0;
      int j2 = int.tryParse(rawScores[i+1]) ?? 0;
      if (j1 > j2) setsP1++;
      if (j2 > j1) setsP2++;
      if (j1 > 0 || j2 > 0) finalScore.add('$j1-$j2');
    }

    final String? winnerId = setsP1 > setsP2 ? match.player1Id : (setsP2 > setsP1 ? match.player2Id : null);

    final updatedMatch = TournamentMatch(
      id: match.id,
      tournamentId: match.tournamentId,
      player1Id: match.player1Id,
      player2Id: match.player2Id,
      winnerId: winnerId,
      score: finalScore,
      round: match.round,
      status: 'played',
      isManualSync: true,
    );

    await _dbService.saveTournamentMatch(updatedMatch);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultado guardado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isAuthorized) return const Scaffold(body: Center(child: Text("Acceso Denegado")));

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Digitalización de Torneo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Carga Rápida de Jugadores'),
            _buildPlayerManualForm(), // REPARADO: Nombre correcto del método
            const SizedBox(height: 40),
            _buildSectionTitle('2. Armado de Llaves (Manual Sync)'),
            _buildFixtureBuilder(),
            const SizedBox(height: 40),
            _buildSectionTitle('3. Control de Sincronización'),
            _buildSyncControl(),
            const SizedBox(height: 40),
            _buildSectionTitle('4. Partidos en Seguimiento'),
            _buildPendingMatchesList(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerManualForm() { // REPARADO: Método definido correctamente
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF2C4A44), borderRadius: BorderRadius.circular(20)),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildInput(_firstNameController, 'Nombre', Icons.person)),
                const SizedBox(width: 10),
                Expanded(child: _buildInput(_lastNameController, 'Apellido', Icons.person_outline)),
              ],
            ),
            const SizedBox(height: 10),
            _buildInput(_phoneController, 'WhatsApp (Cod. Área)', Icons.phone, keyboard: TextInputType.phone),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSavingPlayer ? null : _addManualPlayer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSavingPlayer ? const CircularProgressIndicator() : const Text('AGREGAR JUGADOR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixtureBuilder() {
    return StreamBuilder<List<Player>>(
      stream: _dbService.getPlayersByClub(widget.clubId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final players = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF2C4A44), borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              _buildPlayerDropdown('Jugador 1', players, _selectedP1, (v) => setState(() => _selectedP1 = v)),
              const SizedBox(height: 10),
              _buildPlayerDropdown('Jugador 2', players.where((p) => p.id != _selectedP1).toList(), _selectedP2, (v) => setState(() => _selectedP2 = v)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _round,
                dropdownColor: const Color(0xFF2C4A44),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Ronda', labelStyle: TextStyle(color: Colors.white70)),
                items: ['Octavos', 'Cuartos', 'Semis', 'Final'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _round = v!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _createMatch(_selectedP1, _selectedP2, _round),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00), minimumSize: const Size(double.infinity, 50)),
                child: const Text('CREAR CRUCE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _isManualSyncFinished,
                activeColor: const Color(0xFFCCFF00),
                onChanged: (v) { if (v == true) _finalizeSync(); },
              ),
              const Expanded(child: Text('Finalizar Sincronización Manual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMatchesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc('manual_torneo_${widget.clubId}')
          .collection('matches')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final matches = snapshot.data!.docs;
        if (matches.isEmpty) return const Text('No hay partidos pendientes.', style: TextStyle(color: Colors.white54));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = TournamentMatch.fromFirestore(matches[index] as DocumentSnapshot<Map<String, dynamic>>);
            return _buildMatchCard(match);
          },
        );
      },
    );
  }

  Widget _buildMatchCard(TournamentMatch match) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(match.player1Id).get(),
      builder: (context, p1Snap) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(match.player2Id).get(),
          builder: (context, p2Snap) {
            final p1Name = p1Snap.data?.get('displayName') ?? '...';
            final p2Name = p2Snap.data?.get('displayName') ?? '...';

            return Card(
              color: Colors.white.withOpacity(0.05),
              child: ListTile(
                title: Text('$p1Name vs $p2Name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Ronda: ${match.round}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_note, color: Color(0xFFCCFF00)), onPressed: () => _showScoreModal(match)),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 15), child: Text(title, style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 18, fontWeight: FontWeight.bold)));
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return TextFormField(controller: controller, keyboardType: keyboard, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), prefixIcon: Icon(icon, color: Colors.white24, size: 20), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (v) => v!.isEmpty ? 'Requerido' : null);
  }

  Widget _buildPlayerDropdown(String label, List<Player> players, String? selectedId, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      dropdownColor: const Color(0xFF2C4A44),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      items: players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName))).toList(),
      onChanged: onChanged,
    );
  }
}
