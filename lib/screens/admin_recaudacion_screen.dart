import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminRecaudacionScreen extends StatelessWidget {
  const AdminRecaudacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('ADMIN WALLET (10%)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tournaments').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final tournaments = snapshot.data?.docs ?? [];
          double totalRecaudado = 0;
          int clubesActivos = 0;
          Set<String> clubIds = {};

          for (var doc in tournaments) {
            final data = doc.data() as Map<String, dynamic>;
            final double costo = data['costoInscripcion'] ?? 0.0;
            final int players = data['playerCount'] ?? 0;
            totalRecaudado += (costo * players);
            clubIds.add(data['clubId'] ?? '');
          }
          clubesActivos = clubIds.length;
          double miComision = totalRecaudado * 0.10;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMetricCard("TOTAL RECAUDADO", totalRecaudado, Icons.account_balance_wallet, Colors.white),
                const SizedBox(height: 15),
                _buildMetricCard("TU COMISIÓN (10%)", miComision, Icons.stars, const Color(0xFFCCFF00)),
                const SizedBox(height: 15),
                _buildMetricCard("CLUBES ACTIVOS", clubesActivos.toDouble(), Icons.business, Colors.blueAccent, isCurrency: false),
                
                const SizedBox(height: 40),
                const Text("DESGLOSE POR TORNEO", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const Divider(color: Colors.white10),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    final t = tournaments[index].data() as Map<String, dynamic>;
                    final double costo = t['costoInscripcion'] ?? 0.0;
                    final int players = t['playerCount'] ?? 0;
                    final double subtotal = costo * players;
                    final double fee = subtotal * 0.10;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name']?.toString().toUpperCase() ?? 'Torneo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('clubs').doc(t['clubId']).get(),
                                  builder: (context, clubSnap) {
                                    final clubName = clubSnap.data?.get('name') ?? 'Sede';
                                    return Text(clubName, style: const TextStyle(color: Colors.white38, fontSize: 11));
                                  }
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("\$${NumberFormat("#,###").format(subtotal)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("Comisión: \$${NumberFormat("#,###").format(fee)}", style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 10)),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, double value, IconData icon, Color color, {bool isCurrency = true}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text(
                isCurrency ? "\$${NumberFormat("#,###").format(value)}" : value.toInt().toString(),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }
}
