import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/player_model.dart';
import '../models/club_model.dart';
import '../models/match_request_model.dart';
import '../services/database_service.dart';

class MatchRequestScreen extends StatefulWidget {
  final Player opponent;
  final Position currentUserPosition;

  const MatchRequestScreen({
    super.key,
    required this.opponent,
    required this.currentUserPosition,
  });

  @override
  State<MatchRequestScreen> createState() => _MatchRequestScreenState();
}

class _MatchRequestScreenState extends State<MatchRequestScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Club? _selectedClub;
  String? _selectedSlotId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final allClubs = await _dbService.getClubs().timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          if (allClubs.isNotEmpty) {
            _selectedClub = allClubs.firstWhere((c) => c.id == 'el-pinar-tenis', orElse: () => allClubs.first);
          } else {
            // FALLBACK: Si falla la conexión a Firestore, creamos el club de Guille en memoria
            _selectedClub = Club(
              id: 'el-pinar-tenis',
              name: 'EL PINAR TENIS CLUB',
              address: 'F. Gutiérrez 1348',
              courtCount: 4,
              location: const GeoPoint(-33.3719173, -60.2078407),
              costo_reserva_coins: 15000,
              hourlyPrice: {'day': 15000, 'night': 20000},
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchMaps() async {
    if (_selectedClub == null) return;
    final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${_selectedClub!.location.latitude},${_selectedClub!.location.longitude}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Confirmar Encuentro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)))
        : SingleChildScrollView(
            child: Column(
              children: [
                _buildMapFallback(),
                _buildClubInfoCard(),
                const SizedBox(height: 120), // Espacio para botones Android
              ],
            ),
          ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildMapFallback() {
    if (_selectedClub == null) return const SizedBox();
    return Container(
      height: 180,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_selectedClub!.location.latitude, _selectedClub!.location.longitude),
            zoom: 14
          ),
          markers: {
            Marker(markerId: const MarkerId('club'), position: LatLng(_selectedClub!.location.latitude, _selectedClub!.location.longitude))
          },
        ),
      ),
    );
  }

  Widget _buildClubInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stadium, color: Color(0xFF1A3A34), size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedClub!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A3A34))),
                    Text(_selectedClub!.address, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          InkWell(
            onTap: _launchMaps,
            child: Row(
              children: [
                const Icon(Icons.directions, color: Colors.blue),
                const SizedBox(width: 10),
                const Text("Ir a El Pinar (15 min - 7,1 km)", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("Horarios Disponibles:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildSlotsGrid(),
        ],
      ),
    );
  }

  Widget _buildSlotsGrid() {
    final List<String> fakeSlots = ['18:00', '19:30', '21:00'];
    return Wrap(
      spacing: 10,
      children: fakeSlots.map((time) => ChoiceChip(
        label: Text(time),
        selected: _selectedSlotId == time,
        onSelected: (val) => setState(() => _selectedSlotId = val ? time : null),
        selectedColor: const Color(0xFFCCFF00),
      )).toList(),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCCFF00),
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: _selectedSlotId != null ? () => Navigator.pop(context) : null,
        child: const Text('CONFIRMAR ENCUENTRO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
