import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/weather_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE CONFIGURACIÓN DE PRECIOS DE CANCHA
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// MODALIDAD
// ─────────────────────────────────────────────────────────────────────────────
enum CourtModality { singles, dobles }

extension CourtModalityExt on CourtModality {
  String   get label => this == CourtModality.singles ? 'SINGLES' : 'DOBLES';
  IconData get icon  => this == CourtModality.singles ? Icons.person : Icons.people;
}

class CourtPricing {
  final double priceDaySingles;
  final double priceNightSingles;
  final double priceDayDobles;
  final double priceNightDobles;
  final int    slotMinutes;

  const CourtPricing({
    this.priceDaySingles   = 5000,
    this.priceNightSingles = 8000,
    this.priceDayDobles    = 7000,
    this.priceNightDobles  = 10000,
    this.slotMinutes       = 60,
  });

  factory CourtPricing.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const CourtPricing();
    return CourtPricing(
      priceDaySingles:   (m['priceDaySingles']   ?? m['priceDaySlot']   ?? 5000).toDouble(),
      priceNightSingles: (m['priceNightSingles'] ?? m['priceNightSlot'] ?? 8000).toDouble(),
      priceDayDobles:    (m['priceDayDobles']    ?? 7000).toDouble(),
      priceNightDobles:  (m['priceNightDobles']  ?? 10000).toDouble(),
      slotMinutes:        m['slotMinutes']        ?? 60,
    );
  }

  Map<String, dynamic> toMap() => {
    'priceDaySingles':   priceDaySingles,
    'priceNightSingles': priceNightSingles,
    'priceDayDobles':    priceDayDobles,
    'priceNightDobles':  priceNightDobles,
    'slotMinutes':       slotMinutes,
  };

  double priceFor({required bool isNight, required CourtModality modality}) {
    if (modality == CourtModality.singles) {
      return isNight ? priceNightSingles : priceDaySingles;
    } else {
      return isNight ? priceNightDobles : priceDayDobles;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIPOS DE RESERVA
// ─────────────────────────────────────────────────────────────────────────────
enum ReservationType {
  alquiler,
  claseIndividual,
  claseGrupal,
  whatsapp,
}

extension ReservationTypeExt on ReservationType {
  String get label {
    switch (this) {
      case ReservationType.alquiler:        return 'ALQUILER';
      case ReservationType.claseIndividual: return 'CLASE INDIVIDUAL';
      case ReservationType.claseGrupal:     return 'CLASE GRUPAL';
      case ReservationType.whatsapp:        return 'RESERVA WA';
    }
  }

  String get firestoreKey {
    switch (this) {
      case ReservationType.alquiler:        return 'alquiler';
      case ReservationType.claseIndividual: return 'clase_individual';
      case ReservationType.claseGrupal:     return 'clase_grupal';
      case ReservationType.whatsapp:        return 'manual';
    }
  }

  IconData get icon {
    switch (this) {
      case ReservationType.alquiler:        return Icons.sports_tennis;
      case ReservationType.claseIndividual: return Icons.person;
      case ReservationType.claseGrupal:     return Icons.groups;
      case ReservationType.whatsapp:        return Icons.chat;
    }
  }

  Color get color {
    switch (this) {
      case ReservationType.alquiler:        return const Color(0xFFCCFF00);
      case ReservationType.claseIndividual: return Colors.blueAccent;
      case ReservationType.claseGrupal:     return Colors.purpleAccent;
      case ReservationType.whatsapp:        return Colors.greenAccent;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class CourtScheduleScreen extends StatefulWidget {
  final String clubId;
  final String courtId;
  final String courtName;

  const CourtScheduleScreen({
    super.key,
    required this.clubId,
    required this.courtId,
    required this.courtName,
  });

  @override
  State<CourtScheduleScreen> createState() => _CourtScheduleScreenState();
}

class _CourtScheduleScreenState extends State<CourtScheduleScreen> {
  final WeatherService _weatherService = WeatherService();

  DateTime      _selectedDate = DateTime.now();
  DateTime?     _sunsetTime;
  bool          _hasLights    = true;
  bool          _isLoading    = true;
  String        _userRole     = 'player';
  CourtPricing  _pricing      = const CourtPricing();

  // Multi-select para admin
  final Set<String> _selectedSlots = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Rol del usuario
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (mounted) setState(() => _userRole = userDoc.data()?['role'] ?? 'player');
    }

    // Datos de la cancha (luz + precios)
    final courtDoc = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').doc(widget.courtId)
        .get();

    if (mounted && courtDoc.exists) {
      setState(() {
        _hasLights = courtDoc.data()?['hasLights'] ?? true;
        _pricing   = CourtPricing.fromMap(
            courtDoc.data()?['pricing'] as Map<String, dynamic>?);
      });
    }

    await _loadSunset();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSunset() async {
    final clubDoc = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId).get();
    final GeoPoint? loc = clubDoc.data()?['location'];
    if (loc != null) {
      final sunset = await _weatherService.getSunsetTime(
          loc.latitude, loc.longitude, _selectedDate);
      if (mounted) setState(() => _sunsetTime = sunset);
    }
  }

  bool get _isAdmin => _userRole == 'admin' || _userRole == 'coordinator';

  // ── SLOTS ─────────────────────────────────────────────────────────────────
  List<String> _generateSlots() {
    final slots = <String>[];
    final step  = _pricing.slotMinutes;
    for (int totalMin = 7 * 60; totalMin <= 22 * 60; totalMin += step) {
      final h = totalMin ~/ 60;
      final m = totalMin % 60;
      slots.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    }
    return slots;
  }

  bool _isAfterSunset(String time) {
    if (_sunsetTime == null) return false;
    final parts   = time.split(':');
    final slotDt  = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));
    return slotDt.isAfter(_sunsetTime!);
  }

  /// Un slot está bloqueado si la cancha no tiene luz y ya pasó el ocaso.
  bool _isBlocked(String time) => !_hasLights && _isAfterSunset(time);

  double _priceFor(String time, {CourtModality modality = CourtModality.singles}) =>
      _pricing.priceFor(isNight: _isAfterSunset(time), modality: modality);

  String _formatPrice(double p) => '\$${NumberFormat('#,###').format(p)}';

  // ── NAVEGACIÓN DE FECHA ───────────────────────────────────────────────────
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _selectedSlots.clear();
      _sunsetTime = null;
    });
    _loadSunset();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final slots = _generateSlots();

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: Text('Agenda: ${widget.courtName}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white54, size: 20),
              tooltip: 'Configurar precios',
              onPressed: _showPricingConfig,
            ),
          if (_isAdmin && _selectedSlots.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Color(0xFFCCFF00)),
              tooltip: 'Reservar seleccionados',
              onPressed: () => _showReservationModal(_selectedSlots.toList()..sort()),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)))
          : Column(children: [
        _buildDatePicker(),
        _buildHeader(),
        Expanded(child: _buildSlotList(slots)),
      ]),
    );
  }

  // ── DATE PICKER ───────────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFFCCFF00)),
            onPressed: () => _changeDate(-1),
          ),
          Text(
            DateFormat('EEEE dd MMMM', 'es').format(_selectedDate).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFFCCFF00)),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  // ── HEADER INFO ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _chip(
            _hasLights ? 'LUZ OK' : 'SIN LUZ',
            _hasLights ? Colors.greenAccent : Colors.orange,
            _hasLights ? Icons.lightbulb : Icons.lightbulb_outline,
          ),
          const SizedBox(width: 10),
          if (_sunsetTime != null)
            _chip(
              'OCASO: ${DateFormat('HH:mm').format(_sunsetTime!)}',
              Colors.amber,
              Icons.wb_twilight,
            ),
          const Spacer(),
          _chip(
            '${_pricing.slotMinutes} MIN',
            Colors.white38,
            Icons.timer_outlined,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── LISTA DE SLOTS ────────────────────────────────────────────────────────
  Widget _buildSlotList(List<String> slots) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(widget.courtId)
          .collection('reservations')
          .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
        }
        final reservations = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final time = slots[index];
            final res  = reservations
                .where((d) => d['time'] == time)
                .firstOrNull;
            return _buildSlotTile(time, res);
          },
        );
      },
    );
  }

  // ── SLOT TILE ─────────────────────────────────────────────────────────────
  Widget _buildSlotTile(String time, QueryDocumentSnapshot? res) {
    final blocked  = _isBlocked(time);
    final occupied = res != null;
    final selected = _selectedSlots.contains(time);
    final needsLight = _isAfterSunset(time) && _hasLights;
    final price    = _priceFor(time);

    // Color de fondo según estado
    Color bgColor;
    if (blocked)        bgColor = Colors.black.withOpacity(0.4);
    else if (selected)  bgColor = const Color(0xFFCCFF00).withOpacity(0.15);
    else if (occupied) {
      final type = res['type'] ?? '';
      if (type == 'clase_individual') bgColor = Colors.blueAccent.withOpacity(0.2);
      else if (type == 'clase_grupal') bgColor = Colors.purpleAccent.withOpacity(0.2);
      else if (type == 'manual')       bgColor = Colors.greenAccent.withOpacity(0.1);
      else                             bgColor = Colors.orangeAccent.withOpacity(0.15);
    } else {
      bgColor = Colors.white.withOpacity(0.04);
    }

    return GestureDetector(
      onTap: blocked ? null : () => _handleTap(time, res),
      onLongPress: (_isAdmin && !occupied && !blocked)
          ? () => setState(() {
        if (_selectedSlots.contains(time)) {
          _selectedSlots.remove(time);
        } else {
          _selectedSlots.add(time);
        }
      })
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFCCFF00)
                : blocked
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Hora
          SizedBox(
            width: 52,
            child: Text(time,
                style: TextStyle(
                  color: blocked ? Colors.white24 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
          ),

          // Ícono de luz nocturna
          if (needsLight)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.lightbulb, color: Colors.amber, size: 14),
            ),

          // Estado / nombre
          Expanded(child: _buildSlotLabel(time, res, blocked)),

          // Precio o acción
          if (!blocked && !occupied)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person, size: 10, color: Colors.white38),
                const SizedBox(width: 3),
                Text(_formatPrice(_priceFor(time, modality: CourtModality.singles)),
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people, size: 10, color: Colors.white24),
                const SizedBox(width: 3),
                Text(_formatPrice(_priceFor(time, modality: CourtModality.dobles)),
                    style: const TextStyle(color: Colors.white24, fontSize: 9)),
              ]),
            ]),

          // WhatsApp si tiene teléfono
          if (occupied && res['phone'] != null && res['phone'].toString().isNotEmpty)
            GestureDetector(
              onTap: () => _launchWA(res['phone'], res['playerName'] ?? '', time),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.chat, color: Colors.greenAccent, size: 18),
              ),
            ),

          // Borrar (admin)
          if (occupied && _isAdmin)
            GestureDetector(
              onTap: () => _confirmDelete(res!),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.delete_outline, color: Colors.white24, size: 18),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildSlotLabel(String time, QueryDocumentSnapshot? res, bool blocked) {
    if (blocked) {
      return const Text('SIN LUZ — NO DISPONIBLE',
          style: TextStyle(color: Colors.white24, fontSize: 11));
    }
    if (res == null) {
      return const Text('DISPONIBLE',
          style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold));
    }

    final type = res['type'] ?? '';
    final name = res['playerName'] ?? '';

    String label;
    Color  color;

    switch (type) {
      case 'clase_individual':
        label = 'CLASE INDIVIDUAL${name.isNotEmpty ? ' — $name' : ''}';
        color = Colors.blueAccent;
        break;
      case 'clase_grupal':
        label = 'CLASE GRUPAL${name.isNotEmpty ? ' — $name' : ''}';
        color = Colors.purpleAccent;
        break;
      case 'manual':
        label = 'RESERVA WA${name.isNotEmpty ? ' — $name' : ''}';
        color = Colors.greenAccent;
        break;
      case 'alquiler':
        label = 'ALQUILER${name.isNotEmpty ? ' — $name' : ''}';
        color = const Color(0xFFCCFF00);
        break;
      default:
        label = type.toUpperCase() + (name.isNotEmpty ? ' — $name' : '');
        color = Colors.white70;
    }

    return Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis);
  }

  // ── LÓGICA DE TAP ─────────────────────────────────────────────────────────
  void _handleTap(String time, QueryDocumentSnapshot? res) {
    if (res != null) {
      _showReservationDetails(res);
      return;
    }
    if (_isAdmin) {
      if (_selectedSlots.isEmpty) {
        _showReservationModal([time]);
      } else {
        setState(() {
          if (_selectedSlots.contains(time)) {
            _selectedSlots.remove(time);
          } else {
            _selectedSlots.add(time);
          }
        });
      }
    }
    // Los jugadores por ahora no pueden reservar directamente (flujo pendiente)
  }

  // ── MODAL DE RESERVA (ADMIN) ──────────────────────────────────────────────
  void _showReservationModal(List<String> times) {
    final nameCtrl   = TextEditingController();
    final phoneCtrl  = TextEditingController();
    ReservationType? selectedType;
    CourtModality    modality = CourtModality.singles;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          // Precio dinámico según modalidad seleccionada
          final total = times.fold(
              0.0, (s, t) => s + _priceFor(t, modality: modality));

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20, left: 20, right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A34),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(
                  width: 36, height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                const SizedBox(height: 16),

                // Encabezado con precio dinámico
                Row(children: [
                  const Icon(Icons.access_time, color: Color(0xFFCCFF00), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      times.length == 1
                          ? 'Turno ${times.first}'
                          : '${times.length} turnos: ${times.first} – ${times.last}',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(_formatPrice(total),
                        key: ValueKey(total),
                        style: const TextStyle(color: Color(0xFFCCFF00),
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── SINGLES / DOBLES ────────────────────────────────────────
                const Text('MODALIDAD',
                    style: TextStyle(color: Colors.white54, fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(
                  children: CourtModality.values.map((m) {
                    final sel = modality == m;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() => modality = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(
                              right: m == CourtModality.singles ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFFCCFF00).withOpacity(0.12)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? const Color(0xFFCCFF00) : Colors.white12,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(m.icon,
                                  color: sel ? const Color(0xFFCCFF00) : Colors.white38,
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(m.label,
                                  style: TextStyle(
                                    color: sel ? const Color(0xFFCCFF00) : Colors.white38,
                                    fontSize: 12, fontWeight: FontWeight.bold,
                                  )),
                              const SizedBox(width: 6),
                              Text(_formatPrice(_priceFor(times.first, modality: m)),
                                  style: TextStyle(
                                    color: sel
                                        ? const Color(0xFFCCFF00).withOpacity(0.6)
                                        : Colors.white24,
                                    fontSize: 10,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Contactos recientes
                _buildRecentContactsRow(nameCtrl, phoneCtrl, setModal),

                // Nombre
                _buildField('Nombre del jugador', nameCtrl, Icons.person_outline),
                const SizedBox(height: 10),

                // Teléfono
                _buildField('WhatsApp / Celular', phoneCtrl, Icons.phone_outlined,
                    type: TextInputType.phone),
                const SizedBox(height: 20),

                // ── TIPO DE RESERVA ──────────────────────────────────────────
                const Text('TIPO DE RESERVA',
                    style: TextStyle(color: Colors.white54, fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3.2,
                  children: ReservationType.values.map((type) {
                    final isSelected = selectedType == type;
                    return GestureDetector(
                      onTap: () => setModal(() => selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? type.color.withOpacity(0.2)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? type.color : Colors.white12,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(type.icon,
                                color: isSelected ? type.color : Colors.white38,
                                size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(type.label,
                                  style: TextStyle(
                                    color: isSelected ? type.color : Colors.white54,
                                    fontSize: 10, fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Botón confirmar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedType == null
                        ? null
                        : () async {
                      Navigator.pop(ctx);
                      for (final t in times) {
                        await _createReservation(
                          time:       t,
                          type:       selectedType!,
                          modality:   modality,
                          playerName: nameCtrl.text.trim(),
                          phone:      phoneCtrl.text.trim(),
                        );
                      }
                      if (nameCtrl.text.trim().isNotEmpty) {
                        _saveRecentContact(
                            nameCtrl.text.trim(), phoneCtrl.text.trim());
                      }
                      setState(() => _selectedSlots.clear());
                      if (phoneCtrl.text.trim().isNotEmpty &&
                          (selectedType == ReservationType.whatsapp ||
                              selectedType == ReservationType.alquiler)) {
                        _offerWhatsApp(phoneCtrl.text.trim(),
                            nameCtrl.text.trim(), times);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCCFF00),
                      disabledBackgroundColor: Colors.white10,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      selectedType == null
                          ? 'SELECCIONÁ UN TIPO'
                          : 'CONFIRMAR — ${_formatPrice(total)}',
                      style: TextStyle(
                        color: selectedType == null ? Colors.white24 : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white24, size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildRecentContactsRow(
      TextEditingController nameC, TextEditingController phoneC, StateSetter setModal) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('recent_contacts')
          .orderBy('lastUsed', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RECIENTES',
                style: TextStyle(color: Colors.white38, fontSize: 9,
                    letterSpacing: 1.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: snap.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(data['name'] ?? '',
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.white.withOpacity(0.08),
                      side: const BorderSide(color: Colors.white12),
                      onPressed: () => setModal(() {
                        nameC.text  = data['name']  ?? '';
                        phoneC.text = data['phone'] ?? '';
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ── DETALLES DE RESERVA EXISTENTE ─────────────────────────────────────────
  void _showReservationDetails(QueryDocumentSnapshot res) {
    final data = res.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E3A34),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 36, height: 3,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Text(
              _typeLabelFromKey(data['type'] ?? ''),
              style: const TextStyle(color: Color(0xFFCCFF00),
                  fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 6),
            Text(
              data['playerName'] ?? 'Sin nombre',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (data['phone'] != null && data['phone'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(data['phone'], style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _detailChip('${data['time']}', Icons.access_time),
              const SizedBox(width: 10),
              _detailChip(_formatPrice((data['amount'] ?? 0).toDouble()), Icons.attach_money),
            ]),
            const SizedBox(height: 20),
            if (data['phone'] != null && data['phone'].toString().isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('ENVIAR WHATSAPP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.15),
                    foregroundColor: Colors.greenAccent,
                    side: const BorderSide(color: Colors.greenAccent, width: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _launchWA(data['phone'], data['playerName'] ?? '', data['time']);
                  },
                ),
              ),
            if (_isAdmin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(res);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.redAccent, width: 0.5),
                    ),
                  ),
                  child: const Text('CANCELAR RESERVA'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  String _typeLabelFromKey(String key) {
    for (final t in ReservationType.values) {
      if (t.firestoreKey == key) return t.label;
    }
    return key.toUpperCase();
  }

  // ── CONFIGURACIÓN DE PRECIOS ──────────────────────────────────────────────
  void _showPricingConfig() {
    final daySCtrl   = TextEditingController(
        text: _pricing.priceDaySingles.toInt().toString());
    final nightSCtrl = TextEditingController(
        text: _pricing.priceNightSingles.toInt().toString());
    final dayDCtrl   = TextEditingController(
        text: _pricing.priceDayDobles.toInt().toString());
    final nightDCtrl = TextEditingController(
        text: _pricing.priceNightDobles.toInt().toString());
    int slotMin = _pricing.slotMinutes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 20, left: 20, right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A34),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 36, height: 3,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.tune, color: Color(0xFFCCFF00), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('PRECIOS — ${widget.courtName}',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15))),
                ]),
                const SizedBox(height: 20),

                // ── SINGLES ──────────────────────────────────────────────────
                Row(children: [
                  const Icon(Icons.person, color: Color(0xFFCCFF00), size: 14),
                  const SizedBox(width: 6),
                  const Text('SINGLES',
                      style: TextStyle(color: Color(0xFFCCFF00), fontSize: 10,
                          fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _buildField('Día \$', daySCtrl,
                      Icons.wb_sunny_outlined, type: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField('Noche \$', nightSCtrl,
                      Icons.lightbulb_outline, type: TextInputType.number)),
                ]),
                const SizedBox(height: 16),

                // ── DOBLES ───────────────────────────────────────────────────
                Row(children: [
                  const Icon(Icons.people, color: Colors.purpleAccent, size: 14),
                  const SizedBox(width: 6),
                  const Text('DOBLES',
                      style: TextStyle(color: Colors.purpleAccent, fontSize: 10,
                          fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _buildField('Día \$', dayDCtrl,
                      Icons.wb_sunny_outlined, type: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField('Noche \$', nightDCtrl,
                      Icons.lightbulb_outline, type: TextInputType.number)),
                ]),
                const SizedBox(height: 20),

                // ── DURACIÓN ─────────────────────────────────────────────────
                const Text('DURACIÓN DEL TURNO',
                    style: TextStyle(color: Colors.white54, fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 10),
                Row(children: [30, 60].map((min) {
                  final sel = slotMin == min;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModal(() => slotMin = min),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFFCCFF00).withOpacity(0.12)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? const Color(0xFFCCFF00) : Colors.white12,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text('$min MIN',
                              style: TextStyle(
                                color: sel
                                    ? const Color(0xFFCCFF00)
                                    : Colors.white38,
                                fontWeight: FontWeight.bold, fontSize: 13,
                              )),
                        ),
                      ),
                    ),
                  );
                }).toList()),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newPricing = CourtPricing(
                        priceDaySingles:   double.tryParse(daySCtrl.text)   ?? _pricing.priceDaySingles,
                        priceNightSingles: double.tryParse(nightSCtrl.text) ?? _pricing.priceNightSingles,
                        priceDayDobles:    double.tryParse(dayDCtrl.text)   ?? _pricing.priceDayDobles,
                        priceNightDobles:  double.tryParse(nightDCtrl.text) ?? _pricing.priceNightDobles,
                        slotMinutes:       slotMin,
                      );
                      await FirebaseFirestore.instance
                          .collection('clubs').doc(widget.clubId)
                          .collection('courts').doc(widget.courtId)
                          .update({'pricing': newPricing.toMap()});
                      if (mounted) {
                        setState(() => _pricing = newPricing);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Precios actualizados')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCCFF00),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('GUARDAR PRECIOS',
                        style: TextStyle(color: Colors.black,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Future<void> _createReservation({
    required String          time,
    required ReservationType type,
    required CourtModality   modality,
    String? playerName,
    String? phone,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final price   = _priceFor(time, modality: modality);
    await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').doc(widget.courtId)
        .collection('reservations')
        .add({
      'date':        dateStr,
      'time':        time,
      'type':        type.firestoreKey,
      'modality':    modality.name,   // 'singles' o 'dobles'
      'playerName':  playerName ?? '',
      'phone':       phone ?? '',
      'amount':      price,
      'platformFee': price * 0.10,
      'status':      'confirmed',
      'createdAt':   FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveRecentContact(String name, String phone) async {
    final coll = FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('recent_contacts');
    final existing = await coll.where('name', isEqualTo: name).get();
    if (existing.docs.isEmpty) {
      await coll.add({'name': name, 'phone': phone, 'lastUsed': FieldValue.serverTimestamp()});
    } else {
      await existing.docs.first.reference
          .update({'phone': phone, 'lastUsed': FieldValue.serverTimestamp()});
    }
  }

  void _confirmDelete(QueryDocumentSnapshot res) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text('Cancelar reserva', style: TextStyle(color: Colors.white)),
        content: const Text('¿Confirmás que querés eliminar esta reserva?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('NO', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                res.reference.delete();
              },
              child: const Text('SÍ, CANCELAR',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _offerWhatsApp(String phone, String name, List<String> times) {
    final timeStr = times.length == 1 ? times.first : '${times.first} a ${times.last}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text('¿Enviar confirmación?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Enviar WhatsApp de confirmación a $name por el turno del ${DateFormat('dd/MM').format(_selectedDate)} a las $timeStr.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('AHORA NO')),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('ENVIAR'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.withOpacity(0.2), foregroundColor: Colors.greenAccent),
            onPressed: () {
              Navigator.pop(context);
              _launchWA(phone, name, timeStr);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchWA(String phone, String name, String time) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!clean.startsWith('54')) clean = '549$clean';
    final dateStr = DateFormat('dd/MM').format(_selectedDate);
    final msg = 'Hola $name 👋, te confirmamos tu turno en *${widget.courtName}* '
        'para el *$dateStr a las $time*. ¡Te esperamos! 🎾';
    final url = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}