import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE TARIFAS VIGENTES
// ─────────────────────────────────────────────────────────────────────────────
class ClubPricing {
  final double singlesDay;    // Singles de día
  final double singlesNight;  // Singles de noche (con luz)
  final double doblesDay;     // Dobles de día
  final double doblesNight;   // Dobles de noche (con luz)
  final double claseInd;      // Clase individual
  // Clase grupal = 0 siempre (cuota mensual aparte)

  const ClubPricing({
    this.singlesDay   = 20000,
    this.singlesNight = 25000,
    this.doblesDay    = 28000,
    this.doblesNight  = 35000,
    this.claseInd     = 15000,
  });

  factory ClubPricing.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ClubPricing();
    return ClubPricing(
      singlesDay:   (m['singlesDay']   ?? 20000).toDouble(),
      singlesNight: (m['singlesNight'] ?? 25000).toDouble(),
      doblesDay:    (m['doblesDay']    ?? 28000).toDouble(),
      doblesNight:  (m['doblesNight']  ?? 35000).toDouble(),
      claseInd:     (m['claseInd']     ?? 15000).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'singlesDay':   singlesDay,
    'singlesNight': singlesNight,
    'doblesDay':    doblesDay,
    'doblesNight':  doblesNight,
    'claseInd':     claseInd,
    'claseGrup':    0,
    'updatedAt':    FieldValue.serverTimestamp(),
    'updatedAtStr': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
  };

  // Obtener precio según tipo y horario
  double priceFor({
    required String type,
    required bool   isNight,
    bool            isDobles = false,
  }) {
    switch (type) {
      case 'alquiler':
      case 'manual':
        return isDobles
            ? (isNight ? doblesNight : doblesDay)
            : (isNight ? singlesNight : singlesDay);
      case 'clase_individual':
        return claseInd;
      case 'clase_grupal':
      case 'torneo':
        return 0;
      default:
        return isNight ? singlesNight : singlesDay;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE CONFIGURACIÓN
// ─────────────────────────────────────────────────────────────────────────────
class PricingConfigScreen extends StatefulWidget {
  final String clubId;
  const PricingConfigScreen({super.key, required this.clubId});

  @override
  State<PricingConfigScreen> createState() => _PricingConfigScreenState();
}

class _PricingConfigScreenState extends State<PricingConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading  = true;
  bool _saving   = false;
  String? _lastUpdated;

  late TextEditingController _singlesDayCtrl;
  late TextEditingController _singlesNightCtrl;
  late TextEditingController _doblesDayCtrl;
  late TextEditingController _doblesNightCtrl;
  late TextEditingController _claseIndCtrl;

  @override
  void initState() {
    super.initState();
    _singlesDayCtrl   = TextEditingController();
    _singlesNightCtrl = TextEditingController();
    _doblesDayCtrl    = TextEditingController();
    _doblesNightCtrl  = TextEditingController();
    _claseIndCtrl     = TextEditingController();
    _loadCurrent();
  }

  @override
  void dispose() {
    _singlesDayCtrl.dispose();
    _singlesNightCtrl.dispose();
    _doblesDayCtrl.dispose();
    _doblesNightCtrl.dispose();
    _claseIndCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final doc = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('pricing').doc('current')
        .get();

    final p = ClubPricing.fromMap(
        doc.exists ? doc.data() : null);

    setState(() {
      _singlesDayCtrl.text   = p.singlesDay.toInt().toString();
      _singlesNightCtrl.text = p.singlesNight.toInt().toString();
      _doblesDayCtrl.text    = p.doblesDay.toInt().toString();
      _doblesNightCtrl.text  = p.doblesNight.toInt().toString();
      _claseIndCtrl.text     = p.claseInd.toInt().toString();
      _lastUpdated           = doc.data()?['updatedAtStr']?.toString();
      _loading               = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final newPricing = ClubPricing(
      singlesDay:   double.tryParse(_singlesDayCtrl.text)   ?? 20000,
      singlesNight: double.tryParse(_singlesNightCtrl.text) ?? 25000,
      doblesDay:    double.tryParse(_doblesDayCtrl.text)    ?? 28000,
      doblesNight:  double.tryParse(_doblesNightCtrl.text)  ?? 35000,
      claseInd:     double.tryParse(_claseIndCtrl.text)     ?? 15000,
    );

    await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('pricing').doc('current')
        .set(newPricing.toMap());

    if (mounted) {
      setState(() {
        _saving      = false;
        _lastUpdated = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tarifas actualizadas — aplican desde ahora'),
          backgroundColor: Color(0xFF1A3A34),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F1A),
      appBar: AppBar(
        title: const Text('TARIFAS DEL CLUB',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFFCCFF00)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            color: Colors.blueAccent, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Los precios aplican desde el momento en que '
                            'guardás. Las reservas anteriores mantienen '
                            'su precio original.',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11,
                                height: 1.4),
                          ),
                        ),
                      ]),
                    ),

                    if (_lastUpdated != null) ...[
                      const SizedBox(height: 8),
                      Text('Última actualización: $_lastUpdated',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 10)),
                    ],
                    const SizedBox(height: 28),

                    // ── SINGLES ───────────────────────────────────────────────
                    _sectionHeader(
                        'SINGLES', Icons.person, const Color(0xFFCCFF00)),
                    const SizedBox(height: 4),
                    const Text(
                      'Precio total entre los 2 jugadores por turno de 30 min',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _priceField(
                          'DÍA (sin luz)', _singlesDayCtrl,
                          Icons.wb_sunny_outlined, Colors.white70)),
                      const SizedBox(width: 12),
                      Expanded(child: _priceField(
                          'NOCHE (con luz)', _singlesNightCtrl,
                          Icons.lightbulb, Colors.amber)),
                    ]),
                    const SizedBox(height: 28),

                    // ── DOBLES ────────────────────────────────────────────────
                    _sectionHeader(
                        'DOBLES', Icons.people, Colors.purpleAccent),
                    const SizedBox(height: 4),
                    const Text(
                      'Precio total entre los 4 jugadores por turno de 30 min',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _priceField(
                          'DÍA (sin luz)', _doblesDayCtrl,
                          Icons.wb_sunny_outlined, Colors.white70)),
                      const SizedBox(width: 12),
                      Expanded(child: _priceField(
                          'NOCHE (con luz)', _doblesNightCtrl,
                          Icons.lightbulb, Colors.amber)),
                    ]),
                    const SizedBox(height: 28),

                    // ── CLASES ────────────────────────────────────────────────
                    _sectionHeader(
                        'CLASES', Icons.school, Colors.blueAccent),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _priceField(
                          'CLASE INDIVIDUAL', _claseIndCtrl,
                          Icons.person_outline, Colors.blueAccent)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.groups,
                                    color: Colors.white24, size: 14),
                                const SizedBox(width: 6),
                                const Text('CLASE GRUPAL',
                                    style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                              ]),
                              const SizedBox(height: 8),
                              const Text('\$0',
                                  style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text(
                                'Cuota mensual aparte',
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── TORNEO ────────────────────────────────────────────────
                    _sectionHeader(
                        'TORNEOS', Icons.emoji_events, Colors.orangeAccent),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.15)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline,
                            color: Colors.orangeAccent, size: 14),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Los partidos de torneo no tienen costo de cancha '
                            'para los jugadores. El costo lo absorbe el torneo.',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11,
                                height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 40),

                    // ── GUARDAR ───────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          disabledBackgroundColor:
                              Colors.white.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.black, strokeWidth: 2.5))
                            : const Text('GUARDAR TARIFAS',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color) =>
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      ]);

  Widget _priceField(
    String label,
    TextEditingController ctrl,
    IconData icon,
    Color color,
  ) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.bold),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: const Color(0xFFCCFF00).withOpacity(0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            if (double.tryParse(v) == null) return 'Número inválido';
            return null;
          },
        ),
      ]);
}
