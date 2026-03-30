import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: ocaso aproximado para Buenos Aires (minutos desde medianoche)
// ─────────────────────────────────────────────────────────────────────────────
int _approxSunsetMinutes(DateTime date) {
  const byMonth = [
    1230, // ene ~20:30
    1200, // feb ~20:00
    1155, // mar ~19:15
    1110, // abr ~18:30
    1065, // may ~17:45
    1050, // jun ~17:30
    1065, // jul ~17:45
    1095, // ago ~18:15
    1125, // sep ~18:45
    1170, // oct ~19:30
    1215, // nov ~20:15
    1230, // dic ~20:30
  ];
  return byMonth[date.month - 1];
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO LIVIANO DE CANCHA (para uso interno de esta pantalla)
// ─────────────────────────────────────────────────────────────────────────────
class _CourtInfo {
  final String id;
  final String name;
  final String surface;
  final bool   hasLights;
  final double priceDaySingles;
  final double priceNightSingles;
  final double priceDayDobles;
  final double priceNightDobles;
  // slots son siempre de 30 min
  static const int slotMinutes = 30;

  const _CourtInfo({
    required this.id,
    required this.name,
    required this.surface,
    required this.hasLights,
    required this.priceDaySingles,
    required this.priceNightSingles,
    required this.priceDayDobles,
    required this.priceNightDobles,
  });

  /// Lee solo nombre/superficie/luz del doc de la cancha.
  /// Los precios vienen del club (ver [fromDocWithClubPricing]).
  factory _CourtInfo.fromDoc(DocumentSnapshot doc) =>
      _CourtInfo.fromDocWithClubPricing(doc, const {});

  /// Crea _CourtInfo con precios del club (clubs/{id}/pricing/current).
  /// [clubPricing] tiene campos: singlesDay, singlesNight, doblesDay, doblesNight.
  factory _CourtInfo.fromDocWithClubPricing(
      DocumentSnapshot doc, Map<String, dynamic> clubPricing) {
    final d = doc.data() as Map<String, dynamic>;
    return _CourtInfo(
      id:                doc.id,
      name:              d['courtName']   ?? 'Cancha',
      surface:           d['surfaceType'] ?? 'clay',
      hasLights:         d['hasLights']   ?? false,
      priceDaySingles:   (clubPricing['singlesDay']   ?? 20000).toDouble(),
      priceNightSingles: (clubPricing['singlesNight'] ?? 25000).toDouble(),
      priceDayDobles:    (clubPricing['doblesDay']    ?? clubPricing['singlesDay']   ?? 20000).toDouble(),
      priceNightDobles:  (clubPricing['doblesNight']  ?? clubPricing['singlesNight'] ?? 25000).toDouble(),
    );
  }

  String get surfaceLabel {
    switch (surface) {
      case 'clay':  return 'POLVO DE LADRILLO';
      case 'hard':  return 'CEMENTO';
      case 'grass': return 'CÉSPED';
      default:      return surface.toUpperCase();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER COURTS SCREEN — lista de canchas disponibles del club
// ─────────────────────────────────────────────────────────────────────────────
class PlayerCourtsScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const PlayerCourtsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<PlayerCourtsScreen> createState() => _PlayerCourtsScreenState();
}

class _PlayerCourtsScreenState extends State<PlayerCourtsScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _clubPricing = const {};

  @override
  void initState() {
    super.initState();
    _loadClubPricing();
  }

  Future<void> _loadClubPricing() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('pricing')
          .doc('current')
          .get();
      if (doc.exists && mounted) {
        setState(() => _clubPricing = doc.data() as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFCCFF00),
            onPrimary: Colors.black,
            surface: Color(0xFF2C4A44),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _getCourtImage(String surface, bool hasLights) {
    final suffix = hasLights ? 'noche' : 'dia';
    if (surface == 'clay')  return 'assets/images/courts/polvo_$suffix.png';
    if (surface == 'hard')  return 'assets/images/courts/cemento_$suffix.png';
    if (surface == 'grass') return 'assets/images/courts/cesped_$suffix.png';
    return 'assets/images/courts/polvo_dia.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.clubName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const Text('RESERVAR CANCHA',
                style: TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── DATE PICKER ────────────────────────────────────────────────────
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2C4A44),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFFCCFF00), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE d \'de\' MMMM', 'es').format(_selectedDate),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),

          // ── CANCHAS ────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(widget.clubId)
                  .collection('courts')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFCCFF00)));
                }
                final courts = snap.data!.docs
                    .map((d) => _CourtInfo.fromDocWithClubPricing(d, _clubPricing))
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                if (courts.isEmpty) {
                  return const Center(
                    child: Text('No hay canchas disponibles',
                        style: TextStyle(color: Colors.white38)),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: courts.length,
                  itemBuilder: (ctx, i) => _CourtCard(
                    court:    courts[i],
                    date:     _selectedDate,
                    dateStr:  _dateStr,
                    clubId:   widget.clubId,
                    courtImage: _getCourtImage(
                        courts[i].surface, courts[i].hasLights),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COURT CARD con indicador de disponibilidad
// ─────────────────────────────────────────────────────────────────────────────
class _CourtCard extends StatelessWidget {
  final _CourtInfo court;
  final DateTime   date;
  final String     dateStr;
  final String     clubId;
  final String     courtImage;

  const _CourtCard({
    required this.court,
    required this.date,
    required this.dateStr,
    required this.clubId,
    required this.courtImage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerBookingScreen(
            clubId:    clubId,
            court:     court,
            initialDate: date,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Imagen de fondo
            Positioned.fill(
              child: Image.asset(courtImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF2C4A44))),
            ),
            // Gradiente
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(court.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(court.surfaceLabel,
                      style: const TextStyle(
                          color: Color(0xFFCCFF00),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _pill(
                        '\$${_formatPrice(court.priceDaySingles)} DÍA',
                        Colors.white24),
                    const SizedBox(width: 8),
                    if (court.hasLights)
                      _pill('\$${_formatPrice(court.priceNightSingles)} NOCHE',
                          const Color(0xFFCCFF00).withOpacity(0.25)),
                    const Spacer(),
                    _AvailabilityDot(
                        clubId: clubId,
                        courtId: court.id,
                        dateStr: dateStr),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double p) =>
      NumberFormat('#,###', 'es').format(p.toInt());

  Widget _pill(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      );
}

// Punto verde/rojo de disponibilidad
class _AvailabilityDot extends StatelessWidget {
  final String clubId;
  final String courtId;
  final String dateStr;

  const _AvailabilityDot({
    required this.clubId,
    required this.courtId,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('courts')
          .doc(courtId)
          .collection('reservations')
          .where('date', isEqualTo: dateStr)
          .get(),
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        final hasSlots = count < 8; // estimación simple
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (hasSlots ? Colors.green : Colors.red)
                .withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: (hasSlots ? Colors.green : Colors.red)
                    .withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: hasSlots ? Colors.greenAccent : Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              hasSlots ? 'DISPONIBLE' : 'LLENA',
              style: TextStyle(
                  color: hasSlots ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.bold),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER BOOKING SCREEN — elige turno y método de pago
// ─────────────────────────────────────────────────────────────────────────────
class PlayerBookingScreen extends StatefulWidget {
  final String     clubId;
  final _CourtInfo court;
  final DateTime   initialDate;

  const PlayerBookingScreen({
    super.key,
    required this.clubId,
    required this.court,
    required this.initialDate,
  });

  @override
  State<PlayerBookingScreen> createState() => _PlayerBookingScreenState();
}

class _PlayerBookingScreenState extends State<PlayerBookingScreen> {
  late DateTime _selectedDate;
  String?       _selectedSlot;
  String        _paymentMethod = 'presencial'; // 'mercadopago' | 'presencial'
  String        _modality      = 'singles';    // 'singles' | 'dobles'
  bool          _isBooking = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  // ── Ocaso aproximado para Buenos Aires (minutos desde medianoche) ──────────
  int _sunsetMinutes(DateTime date) {
    const byMonth = [
      1230, // ene ~20:30
      1200, // feb ~20:00
      1155, // mar ~19:15
      1110, // abr ~18:30
      1065, // may ~17:45
      1050, // jun ~17:30
      1065, // jul ~17:45
      1095, // ago ~18:15
      1125, // sep ~18:45
      1170, // oct ~19:30
      1215, // nov ~20:15
      1230, // dic ~20:30
    ];
    return byMonth[date.month - 1];
  }

  bool _isNightSlot(String slot) {
    final p = slot.split(':');
    final totalMin = int.parse(p[0]) * 60 + int.parse(p[1]);
    return totalMin >= _sunsetMinutes(_selectedDate);
  }

  bool _isPast(String slot) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    if (!isToday) return false;
    final p = slot.split(':');
    final slotMin = int.parse(p[0]) * 60 + int.parse(p[1]);
    // El turno empieza en slotMin; lo consideramos pasado si ya comenzó
    return slotMin <= now.hour * 60 + now.minute;
  }

  List<String> _generateSlots() {
    final slots  = <String>[];
    const start  = 8 * 60;  // 08:00
    const end    = 22 * 60; // 22:00 (límite absoluto)
    const step   = _CourtInfo.slotMinutes;
    final sunset = _sunsetMinutes(_selectedDate);

    for (var m = start; m < end; m += step) {
      // Cancha sin luz: el turno debe FINALIZAR en o antes del ocaso
      if (!widget.court.hasLights && m + step > sunset) break;
      final h   = (m ~/ 60).toString().padLeft(2, '0');
      final min = (m % 60).toString().padLeft(2, '0');
      slots.add('$h:$min');
    }
    return slots;
  }

  double _priceFor(String slot) {
    final isNight = _isNightSlot(slot);
    if (_modality == 'dobles') {
      return isNight
          ? widget.court.priceNightDobles
          : widget.court.priceDayDobles;
    }
    return isNight ? widget.court.priceNightSingles : widget.court.priceDaySingles;
  }

  // Formatea la hora del ocaso para mostrar en leyenda
  String _sunsetLabel(DateTime date) {
    final totalMin = _sunsetMinutes(date);
    final h   = (totalMin ~/ 60).toString().padLeft(2, '0');
    final min = (totalMin % 60).toString().padLeft(2, '0');
    return '$h:$min';
  }

  String _formatPrice(double p) =>
      '\$${NumberFormat('#,###', 'es').format(p.toInt())}';

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) return;
    setState(() => _isBooking = true);

    try {
      final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';
      final user = FirebaseAuth.instance.currentUser;
      final price = _priceFor(_selectedSlot!);

      // Verificar que el slot no esté ocupado
      final existing = await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(widget.court.id)
          .collection('reservations')
          .where('date', isEqualTo: _dateStr)
          .where('time', isEqualTo: _selectedSlot)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ese turno ya fue reservado.'),
            backgroundColor: Colors.redAccent,
          ));
        }
        setState(() => _isBooking = false);
        return;
      }

      final status = _paymentMethod == 'mercadopago'
          ? 'pendiente_pago'
          : 'pendiente_confirmacion';

      await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(widget.court.id)
          .collection('reservations')
          .add({
        'date':          _dateStr,
        'time':          _selectedSlot,
        'type':          'alquiler',
        'modality':      _modality,
        'playerName':    user?.displayName ?? 'Jugador',
        'playerId':      uid,
        'phone':         '',
        'amount':        price,
        'platformFee':   price * 0.10,
        'status':        status,
        'paymentMethod': _paymentMethod,
        'createdAt':     FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(price, status);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showSuccessDialog(double price, String status) {
    final isPago = status == 'pendiente_pago';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFCCFF00).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFFCCFF00), size: 36),
            ),
            const SizedBox(height: 16),
            const Text('¡Reserva enviada!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              isPago
                  ? 'Completá el pago de ${_formatPrice(price)} por MercadoPago para confirmar tu turno.'
                  : 'Tu turno quedó pendiente de confirmación. El coordinador te avisará.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (isPago) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: integrar link de pago MP
                },
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('PAGAR AHORA',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCCFF00),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateSlots();

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.court.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(widget.court.surfaceLabel,
                style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('clubs').doc(widget.clubId)
            .collection('courts').doc(widget.court.id)
            .collection('reservations')
            .where('date', isEqualTo: _dateStr)
            .get(),
        builder: (context, snap) {
          final occupied = snap.data?.docs
                  .map((d) => (d.data() as Map)['time']?.toString() ?? '')
                  .toSet() ??
              {};

          return Column(
            children: [
              // ── FECHA ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFFCCFF00), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE d \'de\' MMMM', 'es')
                        .format(_selectedDate),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ]),
              ),

              // ── SELECTOR DE MODALIDAD ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: _PaymentOption(
                      label: 'SINGLES',
                      sublabel: _formatPrice(widget.court.priceDaySingles),
                      icon: Icons.person,
                      selected: _modality == 'singles',
                      onTap: () => setState(() {
                        _modality = 'singles';
                        _selectedSlot = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PaymentOption(
                      label: 'DOBLES',
                      sublabel: _formatPrice(widget.court.priceDayDobles),
                      icon: Icons.people,
                      selected: _modality == 'dobles',
                      onTap: () => setState(() {
                        _modality = 'dobles';
                        _selectedSlot = null;
                      }),
                    ),
                  ),
                ]),
              ),

              // ── LEYENDA OCASO (solo canchas con luz) ─────────────────────
              if (widget.court.hasLights)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: Row(children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Color(0xFFCCFF00), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Turnos nocturnos con luz desde ${_sunsetLabel(_selectedDate)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ]),
                ),

              // ── GRILLA DE TURNOS ─────────────────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (ctx, i) {
                    final slot       = slots[i];
                    final isOccupied = occupied.contains(slot);
                    final isPast     = _isPast(slot);
                    final isSelected = _selectedSlot == slot;
                    final isNight    = _isNightSlot(slot);
                    final isDisabled = isOccupied || isPast;

                    Color bg;
                    Color border;
                    Color textColor;

                    if (isDisabled) {
                      bg        = Colors.white.withOpacity(0.04);
                      border    = Colors.white12;
                      textColor = Colors.white24;
                    } else if (isSelected) {
                      bg        = const Color(0xFFCCFF00).withOpacity(0.15);
                      border    = const Color(0xFFCCFF00);
                      textColor = const Color(0xFFCCFF00);
                    } else {
                      bg        = const Color(0xFF2C4A44);
                      border    = Colors.white12;
                      textColor = Colors.white;
                    }

                    return GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () => setState(
                              () => _selectedSlot = isSelected ? null : slot),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(slot,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            if (!isDisabled)
                              Text(
                                _formatPrice(_priceFor(slot)),
                                style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFCCFF00)
                                        : Colors.white38,
                                    fontSize: 10),
                              ),
                            if (isPast && !isOccupied)
                              const Text('PASADO',
                                  style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 8,
                                      letterSpacing: 1)),
                            if (isOccupied)
                              const Text('OCUPADO',
                                  style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 8,
                                      letterSpacing: 1)),
                            if (!isDisabled && isNight && widget.court.hasLights)
                              const Icon(Icons.lightbulb,
                                  color: Color(0xFFCCFF00), size: 8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── PANEL INFERIOR ───────────────────────────────────────────
              if (_selectedSlot != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2420),
                    border:
                        Border.all(color: Colors.white10),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Resumen
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_selectedSlot · ${_CourtInfo.slotMinutes} min',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                              Text(
                                '${widget.court.name} · ${_modality == 'singles' ? 'Singles' : 'Dobles'}',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12)),
                            ],
                          ),
                          Text(
                            _formatPrice(_priceFor(_selectedSlot!)),
                            style: const TextStyle(
                                color: Color(0xFFCCFF00),
                                fontWeight: FontWeight.bold,
                                fontSize: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Selector de método de pago
                      Row(children: [
                        Expanded(
                          child: _PaymentOption(
                            label: 'PAGAR ONLINE',
                            sublabel: 'MercadoPago',
                            icon: Icons.phone_android,
                            selected: _paymentMethod == 'mercadopago',
                            onTap: () => setState(
                                () => _paymentMethod = 'mercadopago'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PaymentOption(
                            label: 'PAGAR EN CLUB',
                            sublabel: 'Efectivo / transferencia',
                            icon: Icons.store,
                            selected: _paymentMethod == 'presencial',
                            onTap: () => setState(
                                () => _paymentMethod = 'presencial'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),

                      // Botón confirmar
                      ElevatedButton(
                        onPressed: _isBooking ? null : _confirmBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isBooking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.black, strokeWidth: 2))
                            : const Text(
                                'CONFIRMAR RESERVA',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 1),
                              ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: opción de método de pago
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentOption extends StatelessWidget {
  final String   label;
  final String   sublabel;
  final IconData icon;
  final bool     selected;
  final VoidCallback onTap;
  final bool     enabled;
  final Color?   color;

  const _PaymentOption({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? const Color(0xFFCCFF00);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withOpacity(0.1)
              : const Color(0xFF2C4A44),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? activeColor
                  : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: !enabled
                    ? Colors.white24
                    : selected
                        ? activeColor
                        : Colors.white38),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: !enabled
                              ? Colors.white24
                              : selected ? activeColor : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  Text(sublabel,
                      style: TextStyle(
                          color: enabled ? Colors.white38 : Colors.white24,
                          fontSize: 9)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  color: activeColor, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESERVA PICKER SCREEN — entrada al tab Reservas
// Jugador elige fecha + franja horaria → se buscan canchas disponibles
// ─────────────────────────────────────────────────────────────────────────────
class ReservaPickerScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const ReservaPickerScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<ReservaPickerScreen> createState() => _ReservaPickerScreenState();
}

class _ReservaPickerScreenState extends State<ReservaPickerScreen> {
  DateTime _selectedDate = DateTime.now();
  String   _modality     = 'singles'; // 'singles' | 'dobles'

  // Todas las opciones posibles 08:00 a 22:00
  static final List<int> _allTimeOptions = [
    for (int m = 8 * 60; m <= 22 * 60; m += 30) m,
  ];

  int _startMinutes = 9 * 60;  // 09:00
  int _endMinutes   = 11 * 60; // 11:00

  bool _searched = false;

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // Primer slot futuro disponible hoy (redondeado hacia arriba a 30 min)
  int get _firstAvailableMinute {
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    // Redondear hacia arriba al próximo múltiplo de 30
    final next = ((current ~/ 30) + 1) * 30;
    return next;
  }

  // Opciones válidas para DESDE: en días pasados/futuros todas; hoy solo desde ahora
  List<int> get _startOptions {
    if (!_isToday) return _allTimeOptions.where((m) => m < 22 * 60).toList();
    final min = _firstAvailableMinute;
    return _allTimeOptions.where((m) => m >= min && m < 22 * 60).toList();
  }

  String _minToStr(int m) {
    final h   = (m ~/ 60).toString().padLeft(2, '0');
    final min = (m % 60).toString().padLeft(2, '0');
    return '$h:$min';
  }

  // Cuando cambia la fecha, re-validar start/end si ahora son pasados
  void _onDateChanged(DateTime d) {
    setState(() {
      _selectedDate = d;
      _searched = false;
      if (_isToday) {
        final min = _firstAvailableMinute;
        if (_startMinutes < min) {
          _startMinutes = _startOptions.isNotEmpty ? _startOptions.first : min;
          _endMinutes   = _startMinutes + 60;
          if (_endMinutes > 22 * 60) _endMinutes = 22 * 60;
        }
      }
    });
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  int  get _durationMin => _endMinutes - _startMinutes;
  bool get _validRange  => _durationMin >= 30 && _startOptions.contains(_startMinutes);

  List<String> get _slotsInRange {
    final slots = <String>[];
    for (var m = _startMinutes; m < _endMinutes; m += 30) {
      slots.add(_minToStr(m));
    }
    return slots;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFCCFF00),
            onPrimary: Colors.black,
            surface: Color(0xFF2C4A44),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESERVAS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                Text(widget.clubName,
                    style: const TextStyle(
                        color: Color(0xFFCCFF00),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Selector de fecha ─────────────────────────────────────────────
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF162B24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today,
                    color: Color(0xFFCCFF00), size: 18),
                const SizedBox(width: 12),
                Text(
                  DateFormat("EEEE d 'de' MMMM", 'es').format(_selectedDate),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const Spacer(),
                const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white38, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ── Selector franja horaria ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF162B24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FRANJA HORARIA',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Row(children: [
                    // Desde
                    Expanded(child: _TimeDropdown(
                      label: 'DESDE',
                      value: _startMinutes,
                      options: _startOptions,
                      onChanged: (v) => setState(() {
                        _startMinutes = v;
                        if (_endMinutes <= _startMinutes) {
                          _endMinutes = _startMinutes + 60;
                          if (_endMinutes > 22 * 60) _endMinutes = 22 * 60;
                        }
                        _searched = false;
                      }),
                      minToStr: _minToStr,
                    )),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward,
                        color: Color(0xFFCCFF00), size: 18),
                    const SizedBox(width: 10),
                    // Hasta
                    Expanded(child: _TimeDropdown(
                      label: 'HASTA',
                      value: _endMinutes,
                      options: _allTimeOptions
                          .where((m) => m > _startMinutes && m <= 22 * 60)
                          .toList(),
                      onChanged: (v) => setState(() {
                        _endMinutes = v;
                        _searched = false;
                      }),
                      minToStr: _minToStr,
                    )),
                  ]),
                  if (_validRange)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Duración: ${_durationMin ~/ 60}h ${_durationMin % 60 == 0 ? '' : '${_durationMin % 60}min'} · ${_slotsInRange.length} turnos de 30 min',
                        style: const TextStyle(
                            color: Color(0xFFCCFF00),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Selector MODALIDAD ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _modality = 'singles'; _searched = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _modality == 'singles'
                        ? const Color(0xFFCCFF00).withOpacity(0.12)
                        : const Color(0xFF162B24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _modality == 'singles'
                          ? const Color(0xFFCCFF00)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.person,
                        size: 16,
                        color: _modality == 'singles'
                            ? const Color(0xFFCCFF00)
                            : Colors.white38),
                    const SizedBox(width: 6),
                    Text('SINGLES',
                        style: TextStyle(
                            color: _modality == 'singles'
                                ? const Color(0xFFCCFF00)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _modality = 'dobles'; _searched = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _modality == 'dobles'
                        ? const Color(0xFFCCFF00).withOpacity(0.12)
                        : const Color(0xFF162B24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _modality == 'dobles'
                          ? const Color(0xFFCCFF00)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.people,
                        size: 16,
                        color: _modality == 'dobles'
                            ? const Color(0xFFCCFF00)
                            : Colors.white38),
                    const SizedBox(width: 6),
                    Text('DOBLES',
                        style: TextStyle(
                            color: _modality == 'dobles'
                                ? const Color(0xFFCCFF00)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ]),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Aviso si el rango tiene horarios pasados ──────────────────────
          if (_isToday && _startOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No quedan turnos disponibles para hoy.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),

          // ── Botón BUSCAR ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _validRange
                  ? () => setState(() => _searched = true)
                  : null,
              icon: const Icon(Icons.search, color: Colors.black, size: 18),
              label: Text(
                _validRange
                    ? 'BUSCAR CANCHAS DISPONIBLES'
                    : 'Seleccioná un rango válido',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _validRange
                    ? const Color(0xFFCCFF00)
                    : Colors.white12,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Resultados ────────────────────────────────────────────────────
          Expanded(
            child: _searched && _validRange
                ? _CourtsAvailabilityList(
                    clubId:       widget.clubId,
                    clubName:     widget.clubName,
                    dateStr:      _dateStr,
                    date:         _selectedDate,
                    slotsInRange: _slotsInRange,
                    startStr:     _minToStr(_startMinutes),
                    endStr:       _minToStr(_endMinutes),
                    modality:     _modality,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_outlined,
                            color: Colors.white.withOpacity(0.07), size: 72),
                        const SizedBox(height: 16),
                        const Text(
                          'Elegí fecha y horario\npara ver disponibilidad',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white24, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DROPDOWN HORARIO — widget reutilizable para los selectores de hora
// ─────────────────────────────────────────────────────────────────────────────
class _TimeDropdown extends StatelessWidget {
  final String        label;
  final int           value;
  final List<int>     options;
  final ValueChanged<int> onChanged;
  final String Function(int) minToStr;

  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.minToStr,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = options.contains(value) ? value : options.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: safeValue,
              items: options.map((m) => DropdownMenuItem(
                value: m,
                child: Text(minToStr(m),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
              dropdownColor: const Color(0xFF1A3A34),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.expand_more,
                  color: Color(0xFFCCFF00), size: 18),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE CANCHAS CON DISPONIBILIDAD DE FRANJA
// ─────────────────────────────────────────────────────────────────────────────
class _CourtsAvailabilityList extends StatelessWidget {
  final String       clubId;
  final String       clubName;
  final String       dateStr;
  final DateTime     date;
  final List<String> slotsInRange;
  final String       startStr;
  final String       endStr;
  final String       modality;

  const _CourtsAvailabilityList({
    required this.clubId,
    required this.clubName,
    required this.dateStr,
    required this.date,
    required this.slotsInRange,
    required this.startStr,
    required this.endStr,
    required this.modality,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: FirebaseFirestore.instance
          .collection('clubs').doc(clubId)
          .collection('pricing').doc('current')
          .get()
          .then((d) => d.data() ?? <String, dynamic>{}),
      builder: (ctx, pricingSnap) {
        final clubPricing = pricingSnap.data ?? <String, dynamic>{};

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clubs').doc(clubId)
              .collection('courts')
              .snapshots(),
          builder: (ctx2, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
            }
            final courts = snap.data!.docs
                .map((d) => _CourtInfo.fromDocWithClubPricing(d, clubPricing))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            if (courts.isEmpty) {
              return const Center(
                child: Text('No hay canchas en este club',
                    style: TextStyle(color: Colors.white38)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              itemCount: courts.length,
              itemBuilder: (ctx3, i) => _CourtAvailabilityCard(
                court:        courts[i],
                clubId:       clubId,
                clubName:     clubName,
                dateStr:      dateStr,
                date:         date,
                slotsInRange: slotsInRange,
                startStr:     startStr,
                endStr:       endStr,
                modality:     modality,
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE CANCHA CON VERIFICACIÓN DE DISPONIBILIDAD COMPLETA
// ─────────────────────────────────────────────────────────────────────────────
class _CourtAvailabilityCard extends StatelessWidget {
  final _CourtInfo   court;
  final String       clubId;
  final String       clubName;
  final String       dateStr;
  final DateTime     date;
  final List<String> slotsInRange;
  final String       startStr;
  final String       endStr;
  final String       modality;

  const _CourtAvailabilityCard({
    required this.court,
    required this.clubId,
    required this.clubName,
    required this.dateStr,
    required this.date,
    required this.slotsInRange,
    required this.startStr,
    required this.endStr,
    required this.modality,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('clubs').doc(clubId)
          .collection('courts').doc(court.id)
          .collection('reservations')
          .where('date', isEqualTo: dateStr)
          .get(),
      builder: (ctx, snap) {
        // Mientras carga, mostrar skeleton
        if (!snap.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(18),
            ),
          );
        }

        final occupied = snap.data!.docs
            .map((d) => (d.data() as Map)['time']?.toString() ?? '')
            .toSet();

        // Verificar que TODOS los slots de la franja estén libres
        final isAvailable = slotsInRange.every((s) => !occupied.contains(s));

        // Solo mostrar canchas disponibles
        if (!isAvailable) return const SizedBox.shrink();

        // Calcular precio total usando ocaso real + modalidad
        final sunsetMin = _approxSunsetMinutes(date);
        double totalPrice = 0;
        for (final slot in slotsInRange) {
          final p = slot.split(':');
          final slotMin = int.parse(p[0]) * 60 + int.parse(p[1]);
          final isNight = slotMin >= sunsetMin;
          if (modality == 'dobles') {
            totalPrice += isNight ? court.priceNightDobles : court.priceDayDobles;
          } else {
            totalPrice += isNight ? court.priceNightSingles : court.priceDaySingles;
          }
        }

        // Precio referencia por turno (primer slot)
        final firstSlotParts = slotsInRange.first.split(':');
        final firstSlotMin = int.parse(firstSlotParts[0]) * 60 + int.parse(firstSlotParts[1]);
        final firstIsNight = firstSlotMin >= sunsetMin;
        final pricePerSlot = modality == 'dobles'
            ? (firstIsNight ? court.priceNightDobles : court.priceDayDobles)
            : (firstIsNight ? court.priceNightSingles : court.priceDaySingles);
        final modalityLabel = modality == 'dobles' ? 'dobles' : 'singles';

        return GestureDetector(
          onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RangeBookingScreen(
                        clubId:       clubId,
                        clubName:     clubName,
                        court:        court,
                        date:         date,
                        startStr:     startStr,
                        endStr:       endStr,
                        slotsInRange: slotsInRange,
                        totalPrice:   totalPrice,
                        modality:     modality,
                      ),
                    ),
                  ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFCCFF00).withOpacity(0.25),
              ),
            ),
            child: Row(children: [
              // Ícono de cancha
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sports_tennis,
                  color: Color(0xFFCCFF00),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(court.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text(court.surfaceLabel,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    if (court.hasLights) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.lightbulb,
                          color: Color(0xFFCCFF00), size: 11),
                      const Text(' LUZ',
                          style: TextStyle(
                              color: Color(0xFFCCFF00),
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Total: \$${NumberFormat('#,###', 'es').format(totalPrice.toInt())}',
                    style: const TextStyle(
                        color: Color(0xFFCCFF00),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${NumberFormat('#,###', 'es').format(pricePerSlot.toInt())} / turno · $modalityLabel',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10),
                  ),
                ],
              )),

              const Icon(Icons.chevron_right,
                  color: Color(0xFFCCFF00), size: 20),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RANGE BOOKING SCREEN — confirmación de reserva por franja horaria
// ─────────────────────────────────────────────────────────────────────────────
class RangeBookingScreen extends StatefulWidget {
  final String       clubId;
  final String       clubName;
  final _CourtInfo   court;
  final DateTime     date;
  final String       startStr;
  final String       endStr;
  final List<String> slotsInRange;
  final double       totalPrice;
  final String       modality;

  const RangeBookingScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.court,
    required this.date,
    required this.startStr,
    required this.endStr,
    required this.slotsInRange,
    required this.totalPrice,
    required this.modality,
  });

  @override
  State<RangeBookingScreen> createState() => _RangeBookingScreenState();
}

class _RangeBookingScreenState extends State<RangeBookingScreen> {
  String _paymentMethod = 'presencial';
  bool   _isBooking     = false;
  int    _userCoins     = 0;
  bool   _loadingCoins  = true;

  @override
  void initState() {
    super.initState();
    _loadUserCoins();
  }

  Future<void> _loadUserCoins() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loadingCoins = false); return; }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _userCoins    = ((doc.data()?['balance_coins']) ?? 0) as int;
        _loadingCoins = false;
      });
    }
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(widget.date);
  String get _dateLabel =>
      DateFormat("EEEE d 'de' MMMM yyyy", 'es').format(widget.date);
  int get _durationMin =>
      widget.slotsInRange.length * 30;

  String _formatPrice(double p) =>
      '\$${NumberFormat('#,###', 'es').format(p.toInt())}';

  Future<void> _confirmBooking() async {
    setState(() => _isBooking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid  = user?.uid ?? '';

      // Validar coins si el método es coins
      if (_paymentMethod == 'coins') {
        if (_userCoins < widget.totalPrice.toInt()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Coins insuficientes para esta reserva.'),
              backgroundColor: Colors.redAccent,
            ));
          }
          setState(() => _isBooking = false);
          return;
        }
      }

      // Re-verificar disponibilidad en tiempo real
      final existing = await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(widget.court.id)
          .collection('reservations')
          .where('date', isEqualTo: _dateStr)
          .get();

      final occupiedNow = existing.docs
          .map((d) => (d.data())['time']?.toString() ?? '')
          .toSet();

      if (widget.slotsInRange.any((s) => occupiedNow.contains(s))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Algún turno ya fue reservado. Volvé a buscar.'),
            backgroundColor: Colors.redAccent,
          ));
        }
        setState(() => _isBooking = false);
        return;
      }

      final status = _paymentMethod == 'mercadopago'
          ? 'pendiente_pago'
          : _paymentMethod == 'coins'
              ? 'confirmado'
              : 'pendiente_confirmacion';

      final batch = FirebaseFirestore.instance.batch();
      final courtsRef = FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(widget.court.id)
          .collection('reservations');

      final bookingGroupId = 'group_${DateTime.now().millisecondsSinceEpoch}';

      // Crear un doc por cada slot de 30 min
      final sunsetMin = _approxSunsetMinutes(widget.date);
      for (final slot in widget.slotsInRange) {
        final p = slot.split(':');
        final slotMin = int.parse(p[0]) * 60 + int.parse(p[1]);
        final isNight = slotMin >= sunsetMin;
        final priceFor30 = widget.modality == 'dobles'
            ? (isNight ? widget.court.priceNightDobles : widget.court.priceDayDobles)
            : (isNight ? widget.court.priceNightSingles : widget.court.priceDaySingles);

        batch.set(courtsRef.doc(), {
          'date':           _dateStr,
          'time':           slot,
          'type':           'alquiler',
          'modality':       widget.modality,
          'playerName':     user?.displayName ?? 'Jugador',
          'playerId':       uid,
          'phone':          '',
          'amount':         priceFor30,
          'platformFee':    priceFor30 * 0.10,
          'status':         status,
          'paymentMethod':  _paymentMethod,
          'bookingGroupId': bookingGroupId,
          'startRange':     widget.startStr,
          'endRange':       widget.endStr,
          'createdAt':      FieldValue.serverTimestamp(),
        });
      }

      // Verificar que ningún slot ya esté ocupado (race condition check)
      for (final slot in widget.slotsInRange) {
        final conflict = await FirebaseFirestore.instance
            .collection('clubs').doc(widget.clubId)
            .collection('courts').doc(widget.court.id)
            .collection('reservations')
            .where('date', isEqualTo: _dateStr)
            .where('time', isEqualTo: slot)
            .get();
        if (conflict.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('⚠️ Ese turno ya fue reservado por otro jugador. Elegí otro horario.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ));
            setState(() => _isBooking = false);
          }
          return;
        }
      }

      await batch.commit();

      // Registrar en mis_reservaciones del usuario para vista rápida
      try {
        final startParts = widget.startStr.split(':');
        final scheduledAt = Timestamp.fromDate(DateTime(
          widget.date.year, widget.date.month, widget.date.day,
          int.parse(startParts[0]), int.parse(startParts[1]),
        ));
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('my_reservations').add({
          'clubId':        widget.clubId,
          'clubName':      widget.clubName,
          'courtId':       widget.court.id,
          'courtName':     widget.court.name,
          'date':          _dateStr,
          'startTime':     widget.startStr,
          'endTime':       widget.endStr,
          'totalPrice':    widget.totalPrice,
          'type':          'booking',
          'status':        status,
          'paymentMethod': _paymentMethod,
          'scheduledAt':   scheduledAt,
          'createdAt':     FieldValue.serverTimestamp(),
        });
      } catch (_) {} // no bloquear el flujo si falla

      // Descontar coins si pagó con coins
      if (_paymentMethod == 'coins') {
        final totalInt = widget.totalPrice.toInt();
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update({'balance_coins': FieldValue.increment(-totalInt)});
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('coin_transactions').add({
          'amount':      -totalInt,
          'type':        'court_booking',
          'description': 'Reserva ${widget.court.name} · ${widget.startStr}–${widget.endStr}',
          'createdAt':   FieldValue.serverTimestamp(),
          'date':        DateTime.now().toIso8601String(),
        });
      }

      // Notificar al coordinador/admin del club
      final playerName = user?.displayName ?? 'Jugador';
      await _notifyClubCoordinators(
        clubId:     widget.clubId,
        playerName: playerName,
        courtName:  widget.court.name,
        dateLabel:  _dateLabel,
        startStr:   widget.startStr,
        endStr:     widget.endStr,
        total:      widget.totalPrice,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  /// Notifica al coordinador y admin del club sobre la nueva reserva.
  Future<void> _notifyClubCoordinators({
    required String clubId,
    required String playerName,
    required String courtName,
    required String dateLabel,
    required String startStr,
    required String endStr,
    required double total,
  }) async {
    try {
      final msg = '🎾 Reserva: $playerName · $courtName · $dateLabel $startStr–$endStr';
      // Novedad en el panel del club
      await NotificationService.write(
        clubId:  clubId,
        type:    'booking',
        message: msg,
        extra:   {'courtName': courtName, 'date': dateLabel},
      );
      // Push a coordinadores/admins del club
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('admin_club_id', isEqualTo: clubId)
          .where('role', whereIn: ['coordinator', 'admin'])
          .get();
      for (final adminDoc in admins.docs) {
        await PushNotificationService.sendToUser(
          toUid: adminDoc.id,
          title: 'Nueva reserva de cancha',
          body:  '$playerName reservó $courtName · $startStr–$endStr · \$${NumberFormat('#,###', 'es').format(total.toInt())}',
          type:  'booking',
          extra: {'clubId': clubId},
        );
      }
    } catch (_) {}
  }

  void _showSuccessDialog() {
    final isPago = _paymentMethod == 'mercadopago';
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF162B24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFF00).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                color: Color(0xFFCCFF00), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('¡Reserva enviada!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            isPago
                ? 'Completá el pago de ${_formatPrice(widget.totalPrice)} por MercadoPago para confirmar.'
                : 'Tu turno quedó pendiente de confirmación. El coordinador te avisará.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.startStr} – ${widget.endStr} · ${widget.court.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFCCFF00),
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (isPago) ...[
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dlgCtx),
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('PAGAR AHORA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('CERRAR',
                style: TextStyle(color: Colors.white38)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.court.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(widget.court.surfaceLabel,
                style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Resumen de la franja ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF162B24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFCCFF00).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESUMEN DE RESERVA',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 16),
                _summaryRow(Icons.calendar_today, 'FECHA',
                    _dateLabel.toUpperCase()),
                const SizedBox(height: 10),
                _summaryRow(Icons.schedule, 'HORARIO',
                    '${widget.startStr} – ${widget.endStr}'),
                const SizedBox(height: 10),
                _summaryRow(Icons.timer_outlined, 'DURACIÓN',
                    '$_durationMin minutos (${widget.slotsInRange.length} turnos)'),
                const SizedBox(height: 10),
                _summaryRow(Icons.sports_tennis, 'CANCHA',
                    widget.court.name),
                const SizedBox(height: 10),
                _summaryRow(Icons.layers_outlined, 'SUPERFICIE',
                    widget.court.surfaceLabel),
                const Divider(color: Colors.white12, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    Text(
                      _formatPrice(widget.totalPrice),
                      style: const TextStyle(
                          color: Color(0xFFCCFF00),
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Método de pago ────────────────────────────────────────────
          const Text('MÉTODO DE PAGO',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _PaymentOption(
              label:    'PAGAR ONLINE',
              sublabel: 'MercadoPago',
              icon:     Icons.phone_android,
              selected: _paymentMethod == 'mercadopago',
              onTap:    () => setState(() => _paymentMethod = 'mercadopago'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _PaymentOption(
              label:    'PAGAR EN CLUB',
              sublabel: 'Efectivo / transferencia',
              icon:     Icons.store,
              selected: _paymentMethod == 'presencial',
              onTap:    () => setState(() => _paymentMethod = 'presencial'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _PaymentOption(
              icon:     Icons.monetization_on,
              label:    'COINS',
              sublabel: 'Saldo: $_userCoins coins',
              color:    const Color(0xFFCCFF00),
              enabled:  !_loadingCoins && _userCoins >= widget.totalPrice.toInt(),
              selected: _paymentMethod == 'coins',
              onTap:    () => setState(() => _paymentMethod = 'coins'),
            )),
          ]),
          const SizedBox(height: 24),

          // ── Confirmar ─────────────────────────────────────────────────
          ElevatedButton(
            onPressed: _isBooking ? null : _confirmBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _isBooking
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2.5))
                : const Text('CONFIRMAR RESERVA',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) =>
      Row(children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 12)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]);
}
