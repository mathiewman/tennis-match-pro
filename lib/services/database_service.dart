import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';
import '../models/club_model.dart';
import '../models/court_model.dart';
import '../models/match_request_model.dart';
import '../models/tournament_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Helper para escribir novedades en el club
  Future<void> _notify(String clubId, String type, String message,
      [Map<String, dynamic> extra = const {}]) async {
    if (clubId.isEmpty) return;
    final now = DateTime.now();
    try {
      await _db.collection('clubs').doc(clubId)
          .collection('notifications').add({
        'type':      type,
        'message':   message,
        'date':      '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}',
        'time':      '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
        'sortKey':   '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}',
        'createdAt': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (_) {}
  }
  
  final String usersCollection = 'users'; 
  final String clubsCollection = 'clubs';
  final String courtsSubcollection = 'courts';
  final String availabilitySubcollection = 'availability';
  final String matchRequestsCollection = 'match_requests';
  final String matchesCollection = 'matches';
  final String reservationsCollection = 'reservations';
  final String tournamentsCollection = 'tournaments';
  final String tournamentMatchesSubcollection = 'matches';

  // --- RBAC HELPER ---
  Future<bool> _hasEditorPermissions(String uid) async {
    final doc = await _db.collection(usersCollection).doc(uid).get();
    if (!doc.exists) return false;
    final role = doc.data()?['role'];
    return role == 'admin' || role == 'coordinator';
  }

  // --- TOURNAMENT METHODS ---

  Future<void> bulkAddTournamentPlayers(String requestorUid, String clubId, List<Map<String, dynamic>> players) async {
    if (!await _hasEditorPermissions(requestorUid)) throw Exception("Acceso denegado: Permisos insuficientes.");

    final WriteBatch batch = _db.batch();
    for (var playerData in players) {
      final String id = 'manual_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
      final docRef = _db.collection(usersCollection).doc(id);
      
      batch.set(docRef, {
        'uid': id,
        'displayName': playerData['name'] ?? 'Sin Nombre',
        'phone': playerData['phone'] ?? '',
        'category': playerData['category'] ?? '5ta',
        'role': 'player',
        'isManualEntry': true,
        'admin_club_id': clubId,
        'createdAt': FieldValue.serverTimestamp(),
        'balance_coins': 0,
        'status': 'ocupado',
        'availability': playerData['availability'] ?? {},
      });
    }
    await batch.commit();
    // Novedad: jugadores cargados al torneo
    await _notify(clubId, 'player_join',
        '👥 Se cargaron ${players.length} jugador(es) al torneo');
  }

  Future<void> createManualFixture(String requestorUid, String tournamentId, String p1Id, String p2Id, String round) async {
    if (!await _hasEditorPermissions(requestorUid)) throw Exception("Acceso denegado: Permisos insuficientes.");

    final docRef = _db.collection(tournamentsCollection).doc(tournamentId).collection(tournamentMatchesSubcollection).doc();
    final match = TournamentMatch(
      id: docRef.id,
      tournamentId: tournamentId,
      player1Id: p1Id,
      player2Id: p2Id,
      round: round,
      status: 'pending',
    );
    await docRef.set(match.toMap());
  }

  Future<void> saveTournamentMatch(TournamentMatch match) async {
    final docRef = _db
        .collection(tournamentsCollection)
        .doc(match.tournamentId)
        .collection(tournamentMatchesSubcollection)
        .doc(match.id.isEmpty ? null : match.id);
    
    if (match.id.isEmpty) {
      await docRef.set(match.toMap());
    } else {
      await docRef.update(match.toMap());
    }
  }

  Future<List<String>> getIntersectionAvailability(String p1Id, String p2Id) async {
    final p1Doc = await _db.collection(usersCollection).doc(p1Id).get();
    final p2Doc = await _db.collection(usersCollection).doc(p2Id).get();

    if (!p1Doc.exists || !p2Doc.exists) return [];

    final Map<String, dynamic> avail1 = p1Doc.data()?['availability'] ?? {};
    final Map<String, dynamic> avail2 = p2Doc.data()?['availability'] ?? {};

    List<String> intersection = [];
    avail1.forEach((day, slots) {
      if (avail2.containsKey(day) && avail1[day] == avail2[day]) {
        intersection.add("$day: ${avail1[day]}");
      }
    });
    return intersection;
  }

  // --- USER/PLAYER METHODS ---
  Stream<DocumentSnapshot<Map<String, dynamic>>> getPlayerStream(String uid) {
    return _db.collection(usersCollection).doc(uid).snapshots();
  }
  
  Future<void> savePlayer(Player player) async {
    await _db
        .collection(usersCollection)
        .doc(player.id)
        .set(player.toMap(), SetOptions(merge: true));
  }

  Stream<List<Player>> getPlayersByClub(String clubId) {
    return _db
        .collection(usersCollection)
        .where('admin_club_id', isEqualTo: clubId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList());
  }

  Stream<List<Player>> getOpponentsStream({
    required String tennisLevel,
    required String currentUserId,
  }) {
      return _db
        .collection(usersCollection)
        .where('status', isEqualTo: 'disponible')
        .where('tennisLevel', isEqualTo: tennisLevel)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Player.fromFirestore(doc))
            .where((player) => player.id != currentUserId)
            .toList());
  }

  // --- ADMIN METHODS ---
  Future<void> assignCoins(String uid, int amount, {String? clubId}) async {
    await _db.collection(usersCollection).doc(uid).update({
      'balance_coins': FieldValue.increment(amount),
    });
    // Novedad: asignación de coins
    if (clubId != null && clubId.isNotEmpty) {
      final userDoc = await _db.collection(usersCollection).doc(uid).get();
      final name = userDoc.data()?['displayName'] ?? 'Jugador';
      await _notify(clubId, 'coins',
          '💰 Se asignaron $amount coins a $name');
    }
  }

  Future<void> createMockUsers(int count) async {
    final Random random = Random();
    final tennisLevels = ['Principiante', 'Intermedio', 'Avanzado'];
    
    for (int i = 0; i < count; i++) {
      final id = 'mock_user_${DateTime.now().millisecondsSinceEpoch}_$i';
      await _db.collection(usersCollection).doc(id).set({
        'uid': id,
        'displayName': 'Jugador de Prueba $i',
        'email': 'test$i@tennismatch.pro',
        'role': 'player',
        'tennisLevel': tennisLevels[random.nextInt(tennisLevels.length)],
        'eloRating': 1000 + random.nextInt(500),
        'balance_coins': 100,
        'status': 'disponible',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> createMockStadiums(int count) async {
    await seedClubs();
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _db.collection(usersCollection).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // --- COORDINATOR: Club, Court & Schedule Management ---

  Future<String> registerStadium({
    required String ownerId,
    required String name,
    required String address,
    required int courtCount,
    GeoPoint? location,
    String? photoUrl,
  }) async {
    final docRef = await _db.collection(clubsCollection).add({
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'courtCount': courtCount,
      'isActive': true,
      'location': location ?? const GeoPoint(-33.33, -60.21),
      'photoUrl': photoUrl,
      'costo_reserva_coins': 15000,
      'hourlyPrice': {'day': 15000, 'night': 20000},
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateClubPhoto(String clubId, String photoUrl) async {
    await _db.collection(clubsCollection).doc(clubId).update({
      'photoUrl': photoUrl,
    });
  }

  Future<Map<String, dynamic>?> getClubByOwner(String ownerId) async {
    final snapshot = await _db.collection(clubsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return data;
    }
    return null;
  }

  Future<void> addOrUpdateCourt(String clubId, Court court) async {
    final docRef = court.id.isEmpty || court.id.startsWith('temp_')
        ? _db.collection(clubsCollection).doc(clubId).collection(courtsSubcollection).doc()
        : _db.collection(clubsCollection).doc(clubId).collection(courtsSubcollection).doc(court.id);
    
    await docRef.set(court.toMap(), SetOptions(merge: true));
  }

  Stream<List<Court>> getCourtsStream(String clubId) {
    return _db
        .collection(clubsCollection)
        .doc(clubId)
        .collection(courtsSubcollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Court.fromFirestore(doc)).toList());
  }

  // --- AGENDA & SLOTS LOGIC ---

  Stream<QuerySnapshot> getMatchesForDay(String clubId, DateTime date) {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _db.collection(matchesCollection)
        .where('stadium_id', isEqualTo: clubId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .snapshots();
  }

  Stream<QuerySnapshot> getReservationsForDay(String clubId, DateTime date) {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _db.collection(reservationsCollection)
        .where('clubId', isEqualTo: clubId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .snapshots();
  }

  // --- CLUB & MATCH METHODS ---
  Future<List<Club>> getClubs() async {
    final snapshot = await _db.collection(clubsCollection).where('isActive', isEqualTo: true).get();
    return snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getClubAvailabilityStream(String clubId) {
    return _db
        .collection(clubsCollection)
        .doc(clubId)
        .collection(availabilitySubcollection)
        .where('isBooked', isEqualTo: false)
        .where('holdStatus', isEqualTo: 'available')
        .snapshots();
  }

  Future<void> createMatchRequestWithPayment(MatchRequest request) async {
    final senderRef = _db.collection(usersCollection).doc(request.senderId);
    final slotRef = _db.collection(clubsCollection).doc(request.clubId).collection(availabilitySubcollection).doc(request.availabilitySlotId);

    return _db.runTransaction((transaction) async {
      final senderSnapshot = await transaction.get(senderRef);
      if (!senderSnapshot.exists) throw Exception("Usuario no encontrado");
      
      final senderPlayer = Player.fromFirestore(senderSnapshot as DocumentSnapshot<Map<String, dynamic>>);
      if (senderPlayer.balance_coins < request.cost_per_player) throw Exception("Saldo insuficiente");

      transaction.update(senderRef, {'balance_coins': senderPlayer.balance_coins - request.cost_per_player});
      final requestRef = _db.collection(matchRequestsCollection).doc();
      transaction.set(requestRef, request.toMap());

      final matchRef = _db.collection(matchesCollection).doc();
      transaction.set(matchRef, {
        'player1_id': request.senderId,
        'player2_id': request.receiverId,
        'status': 'pending',
        'timestamp': request.dateTime,
        'stadium_id': request.clubId,
        'request_id': requestRef.id,
      });
      transaction.update(slotRef, {'isBooked': true, 'holdStatus': 'booked'});
    });
  }

  Future<void> seedClubs() async {
    final WriteBatch batch = _db.batch();
    final elPinarRef = _db.collection(clubsCollection).doc('el-pinar-tenis');
    batch.set(elPinarRef, {
      'name': 'El Pinar Tenis Club',
      'address': 'F. Gutiérrez 1348',
      'courtCount': 4,
      'location': const GeoPoint(-33.3719173, -60.2078407),
      'costo_reserva_coins': 15000,
      'hourlyPrice': {'day': 15000, 'night': 20000},
      'isActive': true,
    });
    await batch.commit();
  }
}
