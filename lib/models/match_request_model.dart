import 'package:cloud_firestore/cloud_firestore.dart';

class MatchRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String clubId;
  final Timestamp dateTime;
  final String status; // 'pending', 'accepted', 'rejected'
  final Timestamp createdAt;
  final int total_cost;
  final int cost_per_player;
  final String payment_status; // 'pending_second_player', 'completed', 'refunded'
  final String availabilitySlotId; // New field to track the reserved slot

  MatchRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.clubId,
    required this.dateTime,
    this.status = 'pending',
    required this.createdAt,
    required this.total_cost,
    required this.cost_per_player,
    this.payment_status = 'pending_second_player',
    required this.availabilitySlotId,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'clubId': clubId,
      'dateTime': dateTime,
      'status': status,
      'createdAt': createdAt,
      'total_cost': total_cost,
      'cost_per_player': cost_per_player,
      'payment_status': payment_status,
      'availabilitySlotId': availabilitySlotId,
    };
  }

  factory MatchRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MatchRequest(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      clubId: data['clubId'] ?? '',
      dateTime: data['dateTime'] as Timestamp,
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] as Timestamp,
      total_cost: data['total_cost'] ?? 0,
      cost_per_player: data['cost_per_player'] ?? 0,
      payment_status: data['payment_status'] ?? 'pending_second_player',
      availabilitySlotId: data['availabilitySlotId'] ?? '',
    );
  }
}
