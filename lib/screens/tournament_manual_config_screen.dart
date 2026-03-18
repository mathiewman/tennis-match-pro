import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_cropper/image_cropper.dart'; // Importación añadida

class TournamentManualConfigScreen extends StatefulWidget {
  final String clubId;
  const TournamentManualConfigScreen({super.key, required this.clubId});

  @override
  State<TournamentManualConfigScreen> createState() => _TournamentManualConfigScreenState();
}

class _TournamentManualConfigScreenState extends State<TournamentManualConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  
  int _playerCount = 16;
  int _setsPerMatch = 3;
  String _category = '5ta';
  File? _promoImage;
  bool _isCreating = false;

  final List<int> _setOptions = [1, 3, 5];
  final List<String> _categories = ['1era', '2nda', '3era', '4ta', '5ta', '6ta'];

  Future<void> _pickPromoImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final croppedFile = await _cropImage(File(pickedFile.path));
      if (croppedFile != null) {
        setState(() => _promoImage = croppedFile);
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      // aspectRatioPresets se ha movido a uiSettings para AndroidUiSettings y IOSUiSettings
      uiSettings: [ // Configuración de UI para Android/iOS
        AndroidUiSettings(
            toolbarTitle: 'Recortar Imagen',
            toolbarColor: const Color(0xFF1A3A34),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.original,
            ],
        ),
        IOSUiSettings(
          title: 'Recortar Imagen',
          aspectRatioPresets: [
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );
    if (croppedFile != null) {
      return File(croppedFile.path);
    } else {
      return null;
    }
  }

  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final tournamentId = 'tournament_${DateTime.now().millisecondsSinceEpoch}';
      String? promoUrl;

      if (_promoImage != null) {
        try {
          final ref = FirebaseStorage.instance.ref().child('tournaments/promos/$tournamentId.jpg');
          await ref.putFile(_promoImage!).timeout(const Duration(seconds: 15));
          promoUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Error Storage: $e');
        }
      }

      // La cantidad de jugadores ahora siempre se toma de _playerCount
      final int players = _playerCount;

      final double cost = double.tryParse(_costController.text) ?? 0.0;

      await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).set({
        'name': _nameController.text.toUpperCase(),
        'category': _category,
        'clubId': widget.clubId,
        'playerCount': players,
        'promoUrl': promoUrl,
        'setsPerMatch': _setsPerMatch,
        'costoInscripcion': cost,
        'creatorId': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'setup',
        'isManualSyncFinished': false,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Configurar Torneo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 150, // Reverted bottom padding to 150
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nuevo Torneo Manual', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('NOMBRE DEL TORNEO', Icons.emoji_events),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('COSTO DE INSCRIPCIÓN (\$)', Icons.monetization_on),
                  validator: (v) => v!.isEmpty ? 'Ingresá el costo' : null,
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: const Color(0xFF2C4A44),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('CATEGORÍA', Icons.category),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 30),

                const Text('PARTIDOS A:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _setOptions.map((s) => ElevatedButton(
                    onPressed: () => setState(() => _setsPerMatch = s),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _setsPerMatch == s ? const Color(0xFFCCFF00) : Colors.black.withOpacity(0.3),
                      foregroundColor: _setsPerMatch == s ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text('$s SETS'),
                  )).toList(),
                ),
                const SizedBox(height: 30),

                const Text('CANTIDAD DE JUGADORES', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [4, 8, 16, 32].map((n) => _buildQuickCountBtn(n)).toList(),
                ),
                const SizedBox(height: 32), // Mantener un espacio si es necesario o ajustar

                const Text('Imagen de Promoción', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildImagePicker(),
                const SizedBox(height: 30), // Espacio antes del botón Crear Torneo

                // Botón CREAR TORNEO movido aquí
                ElevatedButton(
                  onPressed: _isCreating ? null : _createTournament,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isCreating 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('CREAR TORNEO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 20), // Espacio final para asegurar que el teclado no lo tape
              ],
            ),
          ),
        ),
      ),
      // bottomSheet eliminado
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
      prefixIcon: Icon(icon, color: const Color(0xFFCCFF00), size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }

  Widget _buildQuickCountBtn(int n) {
    bool isSelected = _playerCount == n;
    return ElevatedButton(
      onPressed: () => setState(() => _playerCount = n),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFCCFF00) : Colors.black.withOpacity(0.3), // Color para no seleccionados
        foregroundColor: isSelected ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0, // Añadido para consistencia
      ),
      child: Text('$n'),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickPromoImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
        child: _promoImage != null 
          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_promoImage!, fit: BoxFit.cover))
          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Colors.white24, size: 40), Text('Subir afiche', style: TextStyle(color: Colors.white24))]),
      ),
    );
  }
}