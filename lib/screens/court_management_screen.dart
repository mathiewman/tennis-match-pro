import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/court_model.dart';
import 'court_schedule_screen.dart';

class CourtManagementScreen extends StatefulWidget {
  /// Si se pasa clubId, se usa directamente sin buscar por ownerId.
  /// Útil para el admin que entra a un club ajeno.
  final String? clubId;
  const CourtManagementScreen({super.key, this.clubId});

  @override
  State<CourtManagementScreen> createState() => _CourtManagementScreenState();
}

class _CourtManagementScreenState extends State<CourtManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic>? _myClub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyClub();
  }

  Future<void> _loadMyClub() async {
    // Si viene clubId externo (admin), usarlo directamente
    if (widget.clubId != null && widget.clubId!.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId).get();
      if (mounted && doc.exists) {
        setState(() {
          _myClub    = {...doc.data()!, 'id': doc.id};
          _isLoading = false;
        });
      }
      return;
    }
    // Coordinador normal: buscar por ownerId
    if (_uid != null) {
      final club = await _dbService.getClubByOwner(_uid!);
      if (mounted) {
        setState(() {
          _myClub    = club;
          _isLoading = false;
        });
      }
    }
  }

  void _showEditCourtDialog(Court court) {
    final nameC = TextEditingController(text: court.courtName);
    String surface = court.surfaceType;
    bool lights = court.hasLights;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C4A44),
          title: const Text('Editar Cancha', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nombre de la Pista', labelStyle: TextStyle(color: Colors.white60))),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: surface,
                dropdownColor: const Color(0xFF2C4A44),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Superficie'),
                items: const [
                  DropdownMenuItem(value: 'clay', child: Text('Polvo de Ladrillo')),
                  DropdownMenuItem(value: 'hard', child: Text('Cemento')),
                  DropdownMenuItem(value: 'grass', child: Text('Césped')),
                ],
                onChanged: (v) => setDialogState(() => surface = v!),
              ),
              SwitchListTile(
                title: const Text('Iluminación LED', style: TextStyle(color: Colors.white, fontSize: 14)),
                value: lights,
                activeColor: const Color(0xFFCCFF00),
                onChanged: (v) => setDialogState(() => lights = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.white70))),
            ElevatedButton(
              onPressed: () async {
                final updated = Court(id: court.id, courtName: nameC.text, surfaceType: surface, hasLights: lights);
                await _dbService.addOrUpdateCourt(_myClub!['id'], updated);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00)),
              child: const Text('GUARDAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _getSurfaceName(String type) {
    switch (type) {
      case 'clay': return 'POLVO DE LADRILLO';
      case 'hard': return 'CEMENTO';
      case 'grass': return 'CÉSPED';
      default: return type.toUpperCase();
    }
  }

  String _getCourtImage(String surface, bool hasLights) {
    String suffix = hasLights ? 'noche' : 'dia';
    if (surface == 'clay' || surface == 'POLVO DE LADRILLO') return 'assets/images/courts/polvo_$suffix.png';
    if (surface == 'hard' || surface == 'CEMENTO') return 'assets/images/courts/cemento_$suffix.png';
    if (surface == 'grass' || surface == 'CÉSPED') return 'assets/images/courts/cesped_$suffix.png';
    return 'assets/images/courts/polvo_dia.png';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_myClub == null) return const Scaffold(body: Center(child: Text("No tienes un club registrado")));

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: Text(_myClub!['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Court>>(
        stream: _dbService.getCourtsStream(_myClub!['id']),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final courts = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.all(20.0), child: Text("Mis Canchas", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85),
                  itemCount: courts.length,
                  itemBuilder: (context, index) => _buildCourtCard(courts[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCourtCard(Court court) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtScheduleScreen(clubId: _myClub!['id'], courtId: court.id, courtName: court.courtName))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset(_getCourtImage(court.surfaceType, court.hasLights), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900]))),
            Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.85)])))),
            Positioned(
              top: 10, right: 10,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFCCFF00), size: 20),
                onPressed: () => _showEditCourtDialog(court),
                style: IconButton.styleFrom(backgroundColor: Colors.black26),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(court.courtName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text(_getSurfaceName(court.surfaceType), style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(children: [Icon(court.hasLights ? Icons.lightbulb : Icons.lightbulb_outline, size: 12, color: court.hasLights ? const Color(0xFFCCFF00) : Colors.white24), const SizedBox(width: 5), Text(court.hasLights ? "LUZ OK" : "SIN LUZ", style: TextStyle(color: court.hasLights ? Colors.white : Colors.white24, fontSize: 9))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
