import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String name;
  final String clubId;
  final String category;
  final List<String> playerIds;
  final Map<String, dynamic> settings;
  final bool isManualSyncFinished;
  final int playerCount;
  final String? promoUrl;
  final String? creatorId;
  final int setsPerMatch; // 1, 3 or 5

  Tournament({
    required this.id,
    required this.name,
    required this.clubId,
    required this.category,
    this.playerIds = const [],
    this.settings = const {},
    this.isManualSyncFinished = false,
    this.playerCount = 16,
    this.promoUrl,
    this.creatorId,
    this.setsPerMatch = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'clubId': clubId,
      'category': category,
      'playerIds': playerIds,
      'settings': settings,
      'isManualSyncFinished': isManualSyncFinished,
      'playerCount': playerCount,
      'promoUrl': promoUrl,
      'creatorId': creatorId,
      'setsPerMatch': setsPerMatch,
    };
  }

  factory Tournament.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Tournament(
      id: doc.id,
      name: data['name'] ?? '',
      clubId: data['clubId'] ?? '',
      category: data['category'] ?? '',
      playerIds: List<String>.from(data['playerIds'] ?? []),
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
      isManualSyncFinished: data['isManualSyncFinished'] ?? false,
      playerCount: data['playerCount'] ?? 16,
      promoUrl: data['promoUrl'],
      creatorId: data['creatorId'],
      setsPerMatch: data['setsPerMatch'] ?? 3,
    );
  }
}

class TournamentMatch {
  final String id;
  final String tournamentId;
  final String player1Id;
  final String player2Id;
  final String? winnerId;
  final List<String> score;
  final String round;
  final String status; 
  final Timestamp? scheduledTime;
  final bool isManualSync;

  TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.player1Id,
    required this.player2Id,
    this.winnerId,
    this.score = const [],
    required this.round,
    this.status = 'pending',
    this.scheduledTime,
    this.isManualSync = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'player1Id': player1Id,
      'player2Id': player2Id,
      'winnerId': winnerId,
      'score': score,
      'round': round,
      'status': status,
      'scheduledTime': scheduledTime,
      'isManualSync': isManualSync,
    };
  }

  factory TournamentMatch.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TournamentMatch(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      player1Id: data['player1Id'] ?? '',
      player2Id: data['player2Id'] ?? '',
      winnerId: data['winnerId'],
      score: List<String>.from(data['score'] ?? []),
      round: data['round'] ?? '',
      status: data['status'] ?? 'pending',
      scheduledTime: data['scheduledTime'] as Timestamp?,
      isManualSync: data['isManualSync'] ?? false,
    );
  }
}
