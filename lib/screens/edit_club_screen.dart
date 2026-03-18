import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../models/court_model.dart';

class EditClubScreen extends StatefulWidget {
  final String clubId;
  const EditClubScreen({super.key, required this.clubId});

  @override
  State<EditClubScreen> createState() => _EditClubScreenState();
}

class _EditClubScreenState extends State<EditClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  File? _imageFile;
  String? _currentPhotoUrl;
  final ImagePicker _picker = ImagePicker();
  Position? _currentPosition;
  bool _isSaving = false;
  bool _isLoading = true;
  int _courtCount = 1;
  List<Court> _courts = [];

  @override
  void initState() {
    super.initState();
    _loadClubData();
  }

  Future<void> _loadClubData() async {
    final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).get();
    if (clubDoc.exists) {
      final data = clubDoc.data()!;
      _nameController.text = data['name'] ?? '';
      _addressController.text = data['address'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _currentPhotoUrl = data['photoUrl'];
      _courtCount = data['courtCount'] ?? 1;

      final courtsSnap = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('courts')
          .get();
      
      setState(() {
        _courts = courtsSnap.docs.map((doc) => Court.fromFirestore(doc)).toList();
        if (_courts.isEmpty) {
          _courts = [Court(id: 'temp_0', courtName: 'Cancha 1', surfaceType: 'clay', hasLights: true)];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 60);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _getLocation() async {
    final position = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = position);
  }

  void _updateCourtList(int count) {
    setState(() {
      if (count > _courts.length) {
        for (int i = _courts.length; i < count; i++) {
          _courts.add(Court(
            id: 'temp_$i',
            courtName: 'Cancha ${i + 1}',
            surfaceType: 'clay',
            hasLights: true,
            closingTimeNoLight: '19:30',
          ));
        }
      } else {
        _courts = _courts.sublist(0, count);
      }
      _courtCount = count;
    });
  }

  Future<void> _updateAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? photoUrl = _currentPhotoUrl;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('club_photos/${widget.clubId}.jpg');
        await ref.putFile(_imageFile!);
        photoUrl = await ref.getDownloadURL();
      }

      Map<String, dynamic> updates = {
        'name': _nameController.text.toUpperCase(),
        'address': _addressController.text,
        'phone': _phoneController.text,
        'photoUrl': photoUrl,
        'courtCount': _courtCount,
      };

      if (_currentPosition != null) {
        updates['location'] = GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude);
      }

      await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).update(updates);

      for (var court in _courts) {
        await DatabaseService().addOrUpdateCourt(widget.clubId, court);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Club actualizado con éxito')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(title: const Text('Editar Mi Club'), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePicker(),
                    const SizedBox(height: 30),
                    _buildField(_nameController, 'Nombre del Club', Icons.business),
                    const SizedBox(height: 15),
                    _buildField(_addressController, 'Dirección', Icons.map),
                    const SizedBox(height: 10),
                    _buildLocationSection(),
                    const SizedBox(height: 20),
                    _buildField(_phoneController, 'WhatsApp', Icons.chat), 
                    const SizedBox(height: 30),
                    const Text('Configuración de Canchas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    _buildCourtCounter(),
                    ..._courts.asMap().entries.map((entry) => _buildCourtCard(entry.key, entry.value)),
                    const SizedBox(height: 160),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFF1A3A34),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _updateAll,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          child: _isSaving ? const CircularProgressIndicator(color: Colors.black) : const Text('GUARDAR CAMBIOS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(),
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: _imageFile != null
            ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_imageFile!, fit: BoxFit.cover))
            : (_currentPhotoUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_currentPhotoUrl!, fit: BoxFit.cover))
                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Color(0xFFCCFF00), size: 40), Text('Cambiar foto', style: TextStyle(color: Colors.white60))])),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF2C4A44), builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.camera_alt, color: Color(0xFFCCFF00)), title: const Text('Cámara', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.photo_library, color: Color(0xFFCCFF00)), title: const Text('Galería', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
    ]));
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return TextFormField(controller: controller, keyboardType: keyboard, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white60), prefixIcon: Icon(icon, color: Colors.white24), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), validator: (v) => v!.isEmpty ? 'Requerido' : null);
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        ElevatedButton.icon(onPressed: _getLocation, icon: Icon(Icons.my_location, color: _currentPosition != null ? Colors.green : Colors.black), label: Text(_currentPosition != null ? 'Ubicación Actualizada' : 'Actualizar GPS'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00), foregroundColor: Colors.black)),
        if (_currentPosition != null) ...[const SizedBox(height: 10), Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.bold, fontSize: 12))],
      ]),
    );
  }

  Widget _buildCourtCounter() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('¿Cuántas canchas?', style: TextStyle(color: Colors.white)),
      Row(children: [
        IconButton(icon: const Icon(Icons.remove_circle, color: Colors.white24), onPressed: _courtCount > 1 ? () => _updateCourtList(_courtCount - 1) : null),
        Text('$_courtCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFCCFF00)), onPressed: _courtCount < 15 ? () => _updateCourtList(_courtCount + 1) : null),
      ])
    ]);
  }

  Widget _buildCourtCard(int index, Court court) {
    return Card(
      color: Colors.white.withOpacity(0.05), margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Text('Cancha ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Text('¿Tiene Luz?', style: TextStyle(color: Colors.white60, fontSize: 12)),
            Switch(value: court.hasLights, activeColor: const Color(0xFFCCFF00), onChanged: (v) => setState(() => _courts[index] = Court(id: court.id, courtName: court.courtName, surfaceType: court.surfaceType, hasLights: v, closingTimeNoLight: v ? null : '19:30'))),
          ]),
          DropdownButtonFormField<String>(
            value: court.surfaceType, dropdownColor: const Color(0xFF2C4A44), style: const TextStyle(color: Colors.white),
            items: const [DropdownMenuItem(value: 'clay', child: Text('Polvo de Ladrillo')), DropdownMenuItem(value: 'hard', child: Text('Cemento')), DropdownMenuItem(value: 'grass', child: Text('Césped'))],
            onChanged: (v) => setState(() => _courts[index] = Court(id: court.id, courtName: court.courtName, surfaceType: v!, hasLights: court.hasLights, closingTimeNoLight: court.closingTimeNoLight)),
          ),
        ]),
      ),
    );
  }
}
