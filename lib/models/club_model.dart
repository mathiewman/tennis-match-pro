import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  final String id;
  final String name;
  final String address;
  final int courtCount;
  final Map<String, dynamic> hourlyPrice;
  final GeoPoint location;
  final int costo_reserva_coins;
  final String? photoUrl;
  final String? phone;
  final String? ownerId;

  Club({
    required this.id,
    required this.name,
    required this.address,
    required this.courtCount,
    required this.hourlyPrice,
    required this.location,
    required this.costo_reserva_coins,
    this.photoUrl,
    this.phone,
    this.ownerId,
  });

  factory Club.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Club(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      courtCount: data['courtCount'] ?? 0,
      hourlyPrice: Map<String, dynamic>.from(data['hourlyPrice'] ?? {}),
      location: data['location'] as GeoPoint,
      costo_reserva_coins: data['costo_reserva_coins'] ?? 20000,
      photoUrl: data['photoUrl'],
      phone: data['phone'],
      ownerId: data['ownerId'],
    );
  }
}
