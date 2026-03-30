import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final int eloRating;
  final String tennisLevel;
  final String preferredHand;
  final String status; 
  final GeoPoint? location;
  final Map<String, String> availability;
  final Timestamp? dateOfBirth;
  final int balance_coins;
  final String role; 
  final String? admin_club_id;
  final Timestamp? availableDate;
  final String? availableTimeSlot;
  final String? apodo;
  final String? category;
  final String? manoHabil;
  final String? reves;
  final String? altura;
  final String? peso;

  Player({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.eloRating = 1000,
    this.tennisLevel = 'Principiante',
    this.preferredHand = 'Diestro',
    this.status = 'ocupado',
    this.location,
    this.availability = const {},
    this.dateOfBirth,
    this.balance_coins = 0,
    this.role = 'player',
    this.admin_club_id,
    this.availableDate,
    this.availableTimeSlot,
    this.apodo,
    this.category,
    this.manoHabil,
    this.reves,
    this.altura,
    this.peso,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName':      displayName,
      'email':            email,
      'photoUrl':         photoUrl,
      'eloRating':        eloRating,
      'tennisLevel':      tennisLevel,
      'preferredHand':    preferredHand,
      'status':           status,
      'location':         location,
      'availability':     availability,
      'dateOfBirth':      dateOfBirth,
      'balance_coins':    balance_coins,
      'role':             role,
      'admin_club_id':    admin_club_id,
      'availableDate':    availableDate,
      'availableTimeSlot': availableTimeSlot,
      'apodo':            apodo,
      'category':         category,
      'manoHabil':        manoHabil,
      'reves':            reves,
      'altura':           altura,
      'peso':             peso,
    };
  }

  factory Player.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Player(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      eloRating: data['eloRating'] ?? 1000,
      tennisLevel: data['tennisLevel'] ?? 'Principiante',
      preferredHand: data['preferredHand'] ?? 'Diestro',
      status: data['status'] ?? 'ocupado',
      location: data['location'] as GeoPoint?,
      availability: Map<String, String>.from(data['availability'] ?? {}),
      dateOfBirth: data['dateOfBirth'] as Timestamp?,
      balance_coins: data['balance_coins'] ?? 0,
      role: data['role'] ?? 'player',
      admin_club_id: data['admin_club_id'],
      availableDate: data['availableDate'] as Timestamp?,
      availableTimeSlot: data['availableTimeSlot'],
      apodo:     data['apodo'],
      category:  data['category'],
      manoHabil: data['manoHabil'],
      reves:     data['reves'],
      altura:    data['altura']?.toString(),
      peso:      data['peso']?.toString(),
    );
  }
}
