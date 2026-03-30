import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import '../services/push_notification_service.dart';

class TournamentAutoConfigScreen extends StatefulWidget {
  final String clubId;
  const TournamentAutoConfigScreen({super.key, required this.clubId});

  @override
  State<TournamentAutoConfigScreen> createState() => _TournamentAutoConfigScreenState();
}

class _TournamentAutoConfigScreenState extends State<TournamentAutoConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _playerCount = 16;
  int _setsPerMatch = 3;
  String _category = '5ta';
  String _gender = 'Masculino';
  bool _isFree = false;
  DateTime? _inscriptionDeadline;
  DateTime? _startDate;
  File? _promoImage;
  bool _isCreating = false;

  String _modality = 'Singles';
  final _premioController = TextEditingController();
  Set<String> _selectedCourtNames = {};
  List<Map<String, dynamic>> _availableCourts = [];
  bool _courtsLoaded = false;

  final List<int> _setOptions = [1, 3, 5];
  final List<String> _categories = ['1era', '2nda', '3era', '4ta', '5ta', '6ta'];
  final List<String> _genders = ['Masculino', 'Femenino', 'Mixto'];

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('courts')
          .get();
      if (mounted) {
        setState(() {
          _availableCourts = snap.docs.map((d) {
            final data = d.data();
            return {'id': d.id, 'name': data['courtName']?.toString() ?? 'Cancha'};
          }).toList()
            ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          _courtsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _courtsLoaded = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    _premioController.dispose();
    super.dispose();
  }

  Future<void> _pickPromoImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final croppedFile = await _cropImage(File(pickedFile.path));
      if (croppedFile != null) setState(() => _promoImage = croppedFile);
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
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
    return croppedFile != null ? File(croppedFile.path) : null;
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

      final double cost = _isFree ? 0.0 : (double.tryParse(_costController.text) ?? 0.0);

      await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).set({
        'name': _nameController.text.toUpperCase(),
        'category': _category,
        'gender': _gender,
        'clubId': widget.clubId,
        'playerCount': _playerCount,
        'promoUrl': promoUrl,
        'setsPerMatch': _setsPerMatch,
        'costoInscripcion': cost,
        'isFree': _isFree,
        'description': _descriptionController.text.trim(),
        'creatorId': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
        'type': 'automatic',
        'isManualSyncFinished': false,
        'modality': _modality,
        'premio': _premioController.text.trim(),
        'courtNames': _selectedCourtNames.toList(),
        if (_inscriptionDeadline != null)
          'inscriptionDeadline': Timestamp.fromDate(_inscriptionDeadline!),
        if (_startDate != null)
          'startDate': Timestamp.fromDate(_startDate!),
      });

      await NotificationService.write(
        clubId: widget.clubId,
        type: 'tournament',
        message: '🏆 Nuevo torneo creado: ${_nameController.text.toUpperCase()}',
        extra: {'tournamentId': tournamentId},
      );

      await PushNotificationService.notifyNewTournament(
        clubId: widget.clubId,
        tournamentName: _nameController.text.toUpperCase(),
        category: _category,
      );

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
        title: const Text('Torneo Automático', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFF00).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.25)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFCCFF00), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los jugadores se inscriben solos. Cuando se cierre la inscripción, el admin genera el bracket desde la pantalla del torneo.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Nombre ──────────────────────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('NOMBRE DEL TORNEO', Icons.emoji_events),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 20),

                // ── Inscripción: GRATIS / CON COSTO ─────────────────────────
                const Text('INSCRIPCIÓN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _toggleBtn(label: 'GRATIS', icon: Icons.card_giftcard, selected: _isFree, onTap: () => setState(() { _isFree = true; _costController.clear(); }))),
                  const SizedBox(width: 10),
                  Expanded(child: _toggleBtn(label: 'CON COSTO (\$)', icon: Icons.attach_money, selected: !_isFree, onTap: () => setState(() => _isFree = false))),
                ]),
                if (!_isFree) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputStyle('MONTO (\$)', Icons.monetization_on),
                    validator: (v) => (!_isFree && (v == null || v.isEmpty)) ? 'Ingresá el costo' : null,
                  ),
                ],
                const SizedBox(height: 20),

                // ── Descripción ─────────────────────────────────────────────
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('DESCRIPCIÓN (opcional)', Icons.description_outlined),
                ),
                const SizedBox(height: 20),

                // ── Categoría ───────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: const Color(0xFF2C4A44),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('CATEGORÍA', Icons.category),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 20),

                // ── Género ──────────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _gender,
                  dropdownColor: const Color(0xFF2C4A44),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('GÉNERO', Icons.people),
                  items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: 20),

                // ── Modalidad ───────────────────────────────────────────────────────────
                const Text('MODALIDAD', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _toggleBtn(label: 'SINGLES', icon: Icons.person, selected: _modality == 'Singles', onTap: () => setState(() => _modality = 'Singles'))),
                  const SizedBox(width: 10),
                  Expanded(child: _toggleBtn(label: 'DOBLES', icon: Icons.people, selected: _modality == 'Dobles', onTap: () => setState(() => _modality = 'Dobles'))),
                ]),
                const SizedBox(height: 20),

                // ── Premio ───────────────────────────────────────────────────────────────
                TextFormField(
                  controller: _premioController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('PREMIO (opcional)', Icons.emoji_events_outlined),
                ),
                const SizedBox(height: 20),

                // ── Canchas del torneo ───────────────────────────────────────────────────
                const Text('CANCHAS ASIGNADAS AL TORNEO', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildCourtsSelector(),
                const SizedBox(height: 30),

                // ── Sets por partido ────────────────────────────────────────
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

                // ── Cantidad de jugadores ───────────────────────────────────
                const Text('CANTIDAD DE JUGADORES', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [4, 8, 16, 32].map((n) => _buildQuickCountBtn(n)).toList(),
                ),
                const SizedBox(height: 24),

                // ── Fecha inicio del torneo ─────────────────────────────────
                const Text('FECHA DE INICIO', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildDatePicker(
                  label: _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Seleccionar fecha (opcional)',
                  isSet: _startDate != null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      helpText: 'Fecha de inicio del torneo',
                      builder: (ctx, child) => _datePickerTheme(ctx, child),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  onClear: () => setState(() => _startDate = null),
                ),
                const SizedBox(height: 20),

                // ── Fecha límite de inscripción ─────────────────────────────
                const Text('FECHA LÍMITE DE INSCRIPCIÓN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildDatePicker(
                  label: _inscriptionDeadline != null ? DateFormat('dd/MM/yyyy').format(_inscriptionDeadline!) : 'Sin fecha límite (opcional)',
                  isSet: _inscriptionDeadline != null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _inscriptionDeadline ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      helpText: 'Fecha límite de inscripción',
                      builder: (ctx, child) => _datePickerTheme(ctx, child),
                    );
                    if (picked != null) setState(() => _inscriptionDeadline = picked);
                  },
                  onClear: () => setState(() => _inscriptionDeadline = null),
                ),
                const SizedBox(height: 24),

                // ── Imagen promo ────────────────────────────────────────────
                const Text('Imagen de Promoción', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildImagePicker(),
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: _isCreating ? null : _createTournament,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('CREAR TORNEO AUTOMÁTICO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourtsSelector() {
    if (!_courtsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFFCCFF00), strokeWidth: 2))),
      );
    }
    if (_availableCourts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text('No hay canchas registradas en este club', style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableCourts.map((court) {
        final name = court['name'] as String;
        final selected = _selectedCourtNames.contains(name);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedCourtNames.remove(name);
            } else {
              _selectedCourtNames.add(name);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFCCFF00).withOpacity(0.15) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? const Color(0xFFCCFF00).withOpacity(0.6) : Colors.white10,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sports_tennis, color: selected ? const Color(0xFFCCFF00) : Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(name, style: TextStyle(
                color: selected ? const Color(0xFFCCFF00) : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _toggleBtn({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFCCFF00).withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFFCCFF00).withOpacity(0.6) : Colors.white10, width: selected ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? const Color(0xFFCCFF00) : Colors.white38, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: selected ? const Color(0xFFCCFF00) : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildDatePicker({required String label, required bool isSet, required VoidCallback onTap, required VoidCallback onClear}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSet ? const Color(0xFFCCFF00).withOpacity(0.4) : Colors.white10),
        ),
        child: Row(children: [
          Icon(Icons.event, color: isSet ? const Color(0xFFCCFF00) : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isSet ? Colors.white : Colors.white38, fontSize: 14)),
          const Spacer(),
          if (isSet)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, color: Colors.white38, size: 16),
            ),
        ]),
      ),
    );
  }

  Widget _datePickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFFCCFF00), surface: Color(0xFF1A3A34)),
      ),
      child: child!,
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
    final isSelected = _playerCount == n;
    return ElevatedButton(
      onPressed: () => setState(() => _playerCount = n),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFCCFF00) : Colors.black.withOpacity(0.3),
        foregroundColor: isSelected ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      child: Text('$n'),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickPromoImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: _promoImage != null
          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_promoImage!, fit: BoxFit.cover))
          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_photo_alternate, color: Colors.white24, size: 40),
              Text('Subir afiche', style: TextStyle(color: Colors.white24)),
            ]),
      ),
    );
  }
}
