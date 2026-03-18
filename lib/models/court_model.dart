import 'package:cloud_firestore/cloud_firestore.dart';

class Court {
  final String id;
  final String courtName;
  final String surfaceType; // clay, hard, grass
  final bool hasLights;
  final bool isActive;
  final String? closingTimeNoLight; // Nuevo campo

  Court({
    required this.id,
    required this.courtName,
    required this.surfaceType,
    required this.hasLights,
    this.isActive = true,
    this.closingTimeNoLight,
  });

  Map<String, dynamic> toMap() {
    return {
      'courtName': courtName,
      'surfaceType': surfaceType,
      'hasLights': hasLights,
      'isActive': isActive,
      'closingTimeNoLight': closingTimeNoLight,
    };
  }

  factory Court.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Court(
      id: doc.id,
      courtName: data['courtName'] ?? '',
      surfaceType: data['surfaceType'] ?? 'clay',
      hasLights: data['hasLights'] ?? false,
      isActive: data['isActive'] ?? true,
      closingTimeNoLight: data['closingTimeNoLight'],
    );
  }
}
