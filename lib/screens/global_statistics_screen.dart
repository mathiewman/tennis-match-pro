import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:async/async.dart';
import '../services/database_service.dart';
import '../services/weather_service.dart';
import '../models/court_model.dart';

class GlobalStatisticsScreen extends StatefulWidget {
  final String clubId;

  const GlobalStatisticsScreen({super.key, required this.clubId});

  @override
  State<GlobalStatisticsScreen> createState() => _GlobalStatisticsScreenState();
}

class _GlobalStatisticsScreenState extends State<GlobalStatisticsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final WeatherService _weatherService = WeatherService();
  DateTime _selectedDate = DateTime.now();
  DateTime? _sunsetTime;

  @override
  void initState() {
    super.initState();
    _updateSunsetForSelectedDate();
  }

  Future<void> _updateSunsetForSelectedDate() async {
    final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).get();
    final GeoPoint? loc = clubDoc.data()?['location'];

    if (loc != null) {
      final sunset = await _weatherService.getSunsetTime(loc.latitude, loc.longitude, _selectedDate);
      if (mounted) {
        setState(() {
          _sunsetTime = sunset;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Agenda y Estadísticas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildDatePicker(),
            _buildStatsSummary(),
            _buildCoinsRevenue(),
            const SizedBox(height: 20),
            _buildDailyNews(),
            const SizedBox(height: 100),
          ],
        ),
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
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFFCCFF00)),
            onPressed: () {
              setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
              _updateSunsetForSelectedDate();
            },
          ),
          Text(
            DateFormat('EEEE dd MMMM', 'es').format(_selectedDate).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFFCCFF00)),
            onPressed: () {
              setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
              _updateSunsetForSelectedDate();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    return StreamBuilder<List<Court>>(
      stream: _dbService.getCourtsStream(widget.clubId),
      builder: (context, courtSnapshot) {
        if (!courtSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
        final courts = courtSnapshot.data!;
        final int totalSlotsPossible = courts.length * 32;

        return StreamBuilder<List<QuerySnapshot>>(
          stream: Rx.combineLatest2(
            _dbService.getMatchesForDay(widget.clubId, _selectedDate),
            _dbService.getReservationsForDay(widget.clubId, _selectedDate),
            (QuerySnapshot a, QuerySnapshot b) => [a, b],
          ),
          builder: (context, snapshot) {
            int occupiedCount = 0;
            if (snapshot.hasData) {
              occupiedCount = snapshot.data![0].docs.length + snapshot.data![1].docs.length;
            }
            int freeCount = totalSlotsPossible - occupiedCount;
            if (freeCount < 0) freeCount = 0;
            double occupancyRate = totalSlotsPossible > 0 ? (occupiedCount / totalSlotsPossible) : 0;

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('OCUPACIÓN TOTAL', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                        if (_sunsetTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                            child: Row(
                              children: [
                                const Icon(Icons.wb_twilight, color: Colors.amber, size: 12),
                                const SizedBox(width: 5),
                                Text('OCASO: ${DateFormat('HH:mm').format(_sunsetTime!)}', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 110,
                          width: 110,
                          child: CircularProgressIndicator(
                            value: occupancyRate,
                            strokeWidth: 10,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCCFF00)),
                          ),
                        ),
                        Text(
                          '${(occupancyRate * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBadge('RESERVADOS', '$occupiedCount', Colors.orangeAccent),
                        _buildStatBadge('DISPONIBLES', '$freeCount', Colors.greenAccent),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCoinsRevenue() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getMatchesForDay(widget.clubId, _selectedDate),
      builder: (context, snapshot) {
        int totalCoins = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalCoins += (data['total_cost'] ?? 15000) as int;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFF00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFCCFF00), size: 30),
                const SizedBox(width: 15),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RECAUDACIÓN DEL DÍA', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('Total Coins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Text(
                  NumberFormat('#,###').format(totalCoins),
                  style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDailyNews() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOVEDADES DEL DÍA:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          StreamBuilder<QuerySnapshot>(
            stream: _dbService.getReservationsForDay(widget.clubId, _selectedDate),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
              final reservations = snapshot.data!.docs;

              if (reservations.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(15)),
                  child: const Center(child: Text('Sin actividad para este día', style: TextStyle(color: Colors.white24))),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reservations.length > 5 ? 5 : reservations.length,
                itemBuilder: (context, index) {
                  final res = reservations[index].data() as Map<String, dynamic>;
                  final time = DateFormat('HH:mm').format((res['timestamp'] as Timestamp).toDate());
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xFFCCFF00).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(time, style: const TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RESERVA ACTIVA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('Cancha en uso', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class Rx {
  static Stream<T> combineLatest2<A, B, T>(
    Stream<A> streamA,
    Stream<B> streamB,
    T Function(A a, B b) combiner,
  ) async* {
    A? lastA;
    B? lastB;
    bool hasA = false;
    bool hasB = false;

    await for (final value in StreamGroup.merge([
      streamA.map((a) => _Result(a, null)),
      streamB.map((b) => _Result(null, b)),
    ])) {
      if (value.a != null) {
        lastA = value.a;
        hasA = true;
      }
      if (value.b != null) {
        lastB = value.b;
        hasB = true;
      }
      if (hasA && hasB) {
        yield combiner(lastA as A, lastB as B);
      }
    }
  }
}

class _Result<A, B> {
  final A? a;
  final B? b;
  _Result(this.a, this.b);
}
