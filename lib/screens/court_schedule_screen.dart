import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:async/async.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../services/weather_service.dart';
import '../services/mercado_pago_service.dart';

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
  final DatabaseService _dbService = DatabaseService();
  final WeatherService _weatherService = WeatherService();
  final MercadoPagoService _mpService = MercadoPagoService();
  
  DateTime _selectedDate = DateTime.now();
  DateTime? _sunsetTime;
  bool _hasLights = true;
  bool _isWeatherLoading = false;
  String _userRole = 'player';

  // Multi-select state
  final Set<String> _selectedTimeSlots = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) setState(() => _userRole = userDoc.data()?['role'] ?? 'player');
    }

    final courtDoc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('courts')
        .doc(widget.courtId)
        .get();
    
    if (mounted) {
      setState(() {
        _hasLights = courtDoc.data()?['hasLights'] ?? true;
      });
    }
    _updateSunsetForSelectedDate();
  }

  Future<void> _updateSunsetForSelectedDate() async {
    setState(() => _isWeatherLoading = true);
    final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).get();
    final GeoPoint? loc = clubDoc.data()?['location'];
    if (loc != null) {
      final sunset = await _weatherService.getSunsetTime(loc.latitude, loc.longitude, _selectedDate);
      if (mounted) setState(() { _sunsetTime = sunset; _isWeatherLoading = false; });
    } else {
      if (mounted) setState(() => _isWeatherLoading = false);
    }
  }

  bool get _isAdmin => _userRole == 'admin' || _userRole == 'coordinator';

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int hour = 7; hour <= 22; hour++) {
      slots.add("${hour.toString().padLeft(2, '0')}:00");
      slots.add("${hour.toString().padLeft(2, '0')}:30");
    }
    return slots;
  }

  double _calculatePrice(String time) {
    double price = 10000.0;
    if (_isAfterSunset(time)) {
      price = 15000.0;
    }
    return price;
  }

  bool _isAfterSunset(String time) {
    if (_sunsetTime == null) return false;
    final parts = time.split(':');
    final slotTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));
    return slotTime.isAfter(_sunsetTime!);
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateTimeSlots();

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: Text('Agenda: ${widget.courtName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isAdmin && _selectedTimeSlots.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Color(0xFFCCFF00)),
              onPressed: () => _showAdminSelectionOverlay(_selectedTimeSlots.toList()..sort()),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          _buildSummaryHeader(),
          Expanded(
            child: _isWeatherLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(widget.clubId)
                      .collection('courts')
                      .doc(widget.courtId)
                      .collection('reservations')
                      .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate))
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final reservations = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: slots.length,
                      itemBuilder: (context, index) {
                        final slotTime = slots[index];
                        final res = reservations.where((doc) => doc['time'] == slotTime).firstOrNull;
                        return _buildSlotTile(slotTime, res);
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: Color(0xFFCCFF00)), onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              _selectedTimeSlots.clear();
            });
            _updateSunsetForSelectedDate();
          }),
          Text(DateFormat('EEEE dd MMMM', 'es').format(_selectedDate).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.chevron_right, color: Color(0xFFCCFF00)), onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
              _selectedTimeSlots.clear();
            });
            _updateSunsetForSelectedDate();
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoChip(_hasLights ? "LUZ OK" : "SIN LUZ", _hasLights ? Colors.green : Colors.orange),
          if (_sunsetTime != null)
            _buildInfoChip("OCASO: ${DateFormat('HH:mm').format(_sunsetTime!)}", Colors.amber),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSlotTile(String time, QueryDocumentSnapshot? res) {
    bool isOcupado = res != null;
    bool needsLight = _isAfterSunset(time);
    bool isSelected = _selectedTimeSlots.contains(time);
    String type = isOcupado ? res['type'] : "Libre";
    
    Color color = Colors.green.withOpacity(0.1);
    if (isSelected) color = const Color(0xFFCCFF00).withOpacity(0.2);
    if (isOcupado) {
      if (type == 'clase') color = Colors.blue.withOpacity(0.3);
      else if (type == 'manual') color = const Color(0xFF14261C).withOpacity(0.8); // Color manual diferenciado
      else color = Colors.red.withOpacity(0.2);
    }

    return InkWell(
      onTap: () => _handleSlotTap(time, res),
      onLongPress: _isAdmin && !isOcupado ? () {
        setState(() {
          if (_selectedTimeSlots.contains(time)) {
            _selectedTimeSlots.remove(time);
          } else {
            _selectedTimeSlots.add(time);
          }
        });
      } : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: isSelected ? const Color(0xFFCCFF00) : Colors.white10, width: isSelected ? 2 : 1)
        ),
        child: Row(
          children: [
            Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            if (needsLight) const Icon(Icons.lightbulb, color: Colors.amber, size: 16),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                isOcupado 
                  ? "${type == 'manual' ? 'RESERVADO (WA)' : type.toUpperCase()} - ${res['playerName'] ?? ''}" 
                  : "DISPONIBLE", 
                style: TextStyle(color: isOcupado ? Colors.white70 : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              )
            ),
            if (isOcupado && type == 'manual' && res['phone'] != null)
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.greenAccent, size: 20),
                onPressed: () => _launchWhatsApp(res['phone'], res['playerName'], time),
              ),
            if (!isOcupado) Text("\$${NumberFormat("#,###").format(_calculatePrice(time))}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            if (isOcupado && _isAdmin) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18), onPressed: () => res.reference.delete()),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone, String name, String time) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('54')) cleanPhone = '549$cleanPhone';
    final dateStr = DateFormat('dd/MM').format(_selectedDate);
    final message = "Hola $name, te confirmo tu turno en El Pinar Tenis Club para el día $dateStr a las $time. ¡Te esperamos!";
    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _handleSlotTap(String time, QueryDocumentSnapshot? res) {
    if (res != null) {
      if (res['type'] == 'clase') _showClassDetails(res);
      return;
    }
    
    if (_isAdmin) {
      if (_selectedTimeSlots.isEmpty) {
        _showAdminSelectionOverlay([time]);
      } else {
        setState(() {
          if (_selectedTimeSlots.contains(time)) {
            _selectedTimeSlots.remove(time);
          } else {
            _selectedTimeSlots.add(time);
          }
        });
      }
    } else {
      _showPlayerReservationDialog(time);
    }
  }

  void _showAdminSelectionOverlay(List<String> times) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool registerCommission = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C4A44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Reserva Manual - ${times.join(', ')}", style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildContactSuggestions(nameController, phoneController, setDialogState),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Nombre del Jugador", labelStyle: TextStyle(color: Colors.white60)),
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "WhatsApp / Celular", labelStyle: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text("Registrar Comisión", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: registerCommission,
                  activeColor: const Color(0xFFCCFF00),
                  onChanged: (v) => setDialogState(() => registerCommission = v),
                ),
                const SizedBox(height: 12),
                _adminOption(
                  icon: Icons.school, 
                  color: Colors.blueAccent, 
                  label: "MARCAR COMO CLASE", 
                  onTap: () { 
                    Navigator.pop(context); 
                    for (var t in times) {
                      _createReservation(t, 'clase', playerName: nameController.text, phone: phoneController.text, commission: registerCommission);
                    }
                    setState(() => _selectedTimeSlots.clear());
                  }
                ),
                const SizedBox(height: 12),
                _adminOption(
                  icon: Icons.chat, 
                  color: Colors.greenAccent, 
                  label: "RESERVAR TURNO (WA)", 
                  onTap: () { 
                    Navigator.pop(context); 
                    for (var t in times) {
                      _createReservation(t, 'manual', playerName: nameController.text, phone: phoneController.text, commission: registerCommission);
                    }
                    // Guardar en contactos recientes
                    if (nameController.text.isNotEmpty) {
                      _saveRecentContact(nameController.text, phoneController.text);
                    }
                    setState(() => _selectedTimeSlots.clear());
                  }
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR"))],
        ),
      ),
    );
  }

  Widget _buildContactSuggestions(TextEditingController nameC, TextEditingController phoneC, StateSetter setDialogState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('recent_contacts')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
        return Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(data['name'], style: const TextStyle(fontSize: 10)),
                  onPressed: () {
                    setDialogState(() {
                      nameC.text = data['name'];
                      phoneC.text = data['phone'] ?? '';
                    });
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _saveRecentContact(String name, String phone) async {
    final coll = FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).collection('recent_contacts');
    final existing = await coll.where('name', isEqualTo: name).get();
    if (existing.docs.isEmpty) {
      await coll.add({'name': name, 'phone': phone, 'lastUsed': FieldValue.serverTimestamp()});
    } else {
      await existing.docs.first.reference.update({'phone': phone, 'lastUsed': FieldValue.serverTimestamp()});
    }
  }

  Widget _adminOption({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 15),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _createReservation(String time, String type, {String? playerName, String? phone, bool commission = false}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final price = _calculatePrice(time);
    
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('courts')
        .doc(widget.courtId)
        .collection('reservations')
        .add({
      'date': dateStr,
      'time': time,
      'type': type,
      'playerName': playerName,
      'phone': phone,
      'amount': price,
      'platformFee': commission ? price * 0.10 : 0.0,
      'isCommissionRegistered': commission,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'confirmed',
    });
  }

  void _showPlayerReservationDialog(String time) {
    double price = _calculatePrice(time);
    double fee = price * 0.10;
    double total = price + fee;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text("Confirmar Reserva", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _priceRow("Alquiler Cancha", price),
            _priceRow("Tasa de Servicio (10%)", fee),
            const Divider(color: Colors.white10),
            _priceRow("TOTAL A PAGAR", total, isTotal: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processPayment(time, total);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00)),
            child: const Text("PAGAR AHORA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _priceRow(String label, double val, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? Colors.white : Colors.white70, fontSize: isTotal ? 14 : 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text("\$${NumberFormat("#,###").format(val)}", style: TextStyle(color: isTotal ? const Color(0xFFCCFF00) : Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _processPayment(String time, double total) async {
    final user = FirebaseAuth.instance.currentUser;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final docRef = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('courts')
        .doc(widget.courtId)
        .collection('reservations')
        .add({
      'date': dateStr,
      'time': time,
      'type': 'jugador',
      'userId': user?.uid,
      'playerName': user?.displayName,
      'amount': total,
      'platformFee': total * (0.10 / 1.10), // Comisión sobre el total
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Iniciando pago... Tienes 15 minutos para completar.")));
    Future.delayed(const Duration(minutes: 15), () async {
      final snap = await docRef.get();
      if (snap.exists && snap.data()?['status'] == 'pending') {
        await docRef.delete();
      }
    });
  }

  void _showClassDetails(QueryDocumentSnapshot res) {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2C4A44),
      title: const Text("Lista de Alumnos"),
      content: const Text("Módulo de asistencia en desarrollo...", style: TextStyle(color: Colors.white70)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CERRAR"))],
    ));
  }
}
