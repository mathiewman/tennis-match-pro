import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../models/court_model.dart';
import 'club_dashboard_screen.dart';

class RegisterClubScreen extends StatefulWidget {
  const RegisterClubScreen({super.key});

  @override
  State<RegisterClubScreen> createState() => _RegisterClubScreenState();
}

class _RegisterClubScreenState extends State<RegisterClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  int _courtCount = 1;
  List<Court> _courts = [Court(id: 'temp_0', courtName: 'Cancha 1', surfaceType: 'clay', hasLights: true)];
  Position? _currentPosition;
  bool _isSaving = false;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 60);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al acceder a la cámara: $e')));
    }
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al obtener GPS. Activa la ubicación.')));
    }
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, captura la ubicación GPS del club')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final db = DatabaseService();

      // 1. Intentar subir imagen (con fallback si falla Storage)
      String? photoUrl;
      if (_imageFile != null) {
        try {
          final ref = FirebaseStorage.instance.ref().child('club_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(_imageFile!);
          photoUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Storage error (procediendo sin foto): $e');
        }
      }

      // 2. Registrar Club
      final clubId = await db.registerStadium(
        ownerId: uid!,
        name: _nameController.text.toUpperCase(),
        address: _addressController.text.toUpperCase(),
        courtCount: _courtCount,
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        photoUrl: photoUrl,
      );

      // 3. Guardar Canchas
      for (var court in _courts) {
        await db.addOrUpdateCourt(clubId, court);
      }

      // 4. Vincular coordinador con el club
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update({'admin_club_id': clubId}).catchError((_) {});
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ClubDashboardScreen(clubId: clubId)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(title: const Text('Registrar Mi Club'), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 30),
              _buildField(_nameController, 'Nombre del Club', Icons.business),
              const SizedBox(height: 15),
              _buildAddressField(),
              const SizedBox(height: 10),
              _buildLocationSection(),
              const SizedBox(height: 20),
              _buildWhatsAppField(),
              const SizedBox(height: 30),
              const Text('Canchas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              _buildCourtCounter(),
              ..._courts.asMap().entries.map((entry) => _buildCourtCard(entry.key, entry.value)),
              const SizedBox(height: 30),
              _buildSaveButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: _imageFile != null
            ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_imageFile!, fit: BoxFit.cover))
            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Color(0xFFCCFF00), size: 40), Text('Subir foto real', style: TextStyle(color: Colors.white60))]),
      ),
    );
  }

  void _showImageSourceDialog() {
    // Forzar cierre del teclado en Android
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF2C4A44),
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xFFCCFF00)),
                  title: const Text('Cámara', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFFCCFF00)),
                  title: const Text('Galería', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white60), prefixIcon: Icon(icon, color: Colors.white24), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
      validator: (v) => v!.isEmpty ? 'Requerido' : null,
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: 'Dirección', labelStyle: const TextStyle(color: Colors.white60), prefixIcon: const Icon(Icons.map, color: Colors.white24), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
      validator: (v) => v!.isEmpty ? 'Requerido' : null,
    );
  }

  Widget _buildWhatsAppField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: 'WhatsApp Reservas', labelStyle: const TextStyle(color: Colors.white60), prefixIcon: const Icon(Icons.phone, color: Colors.white24), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
      validator: (v) {
        if (v == null || v.isEmpty) return 'El WhatsApp es obligatorio';
        if (v.length < 8) return 'Ingresá al menos 8 dígitos';
        return null;
      },
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _getLocation,
            icon: Icon(Icons.my_location, color: _currentPosition != null ? Colors.green : Colors.black),
            label: Text(_currentPosition != null ? 'Ubicación Capturada' : 'Capturar Ubicación GPS'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00), foregroundColor: Colors.black),
          ),
          if (_currentPosition != null) ...[
            const SizedBox(height: 10),
            Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ],
      ),
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
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              Text('Cancha ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('¿Luz?', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Switch(value: court.hasLights, activeColor: const Color(0xFFCCFF00), onChanged: (v) => setState(() => _courts[index] = Court(id: court.id, courtName: court.courtName, surfaceType: court.surfaceType, hasLights: v, closingTimeNoLight: v ? null : '19:30'))),
            ]),
            DropdownButtonFormField<String>(
              value: court.surfaceType,
              dropdownColor: const Color(0xFF2C4A44),
              style: const TextStyle(color: Colors.white),
              items: const [DropdownMenuItem(value: 'clay', child: Text('Polvo')), DropdownMenuItem(value: 'hard', child: Text('Cemento')), DropdownMenuItem(value: 'grass', child: Text('Césped'))],
              onChanged: (v) => setState(() => _courts[index] = Court(id: court.id, courtName: court.courtName, surfaceType: v!, hasLights: court.hasLights, closingTimeNoLight: court.closingTimeNoLight)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveAll,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      child: _isSaving ? const CircularProgressIndicator(color: Colors.black) : const Text('GUARDAR CLUB Y CANCHAS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }
}
