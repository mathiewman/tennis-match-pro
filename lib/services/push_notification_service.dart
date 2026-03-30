import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// HANDLER GLOBAL (debe estar fuera de toda clase — nivel top-level)
// Maneja notificaciones cuando la app está CERRADA o en BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  // Firebase ya inicializado en main.dart antes de llamar esto
  debugPrint('🔔 [BG] ${message.notification?.title} — ${message.data}');
}

// ─────────────────────────────────────────────────────────────────────────────
// TIPOS DE NOTIFICACIÓN — identificadores para routing al abrir la app
// ─────────────────────────────────────────────────────────────────────────────
class NotifType {
  static const matchSlot      = 'match_slot';      // turno de torneo asignado
  static const orderUpdate    = 'order_update';    // pedido confirmado/listo
  static const matchRequest   = 'match_request';   // alguien te desafía
  static const matchAccepted  = 'match_accepted';  // tu propuesta fue aceptada
  static const matchRejected  = 'match_rejected';  // tu propuesta fue rechazada
  static const matchReminder  = 'match_reminder';  // recordatorio de partido
  static const matchCancelled = 'match_cancelled'; // partido cancelado
  static const newTournament  = 'new_tournament';  // torneo nuevo en el club
  static const roundDeadline  = 'round_deadline';  // ronda por vencer
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db        = FirebaseFirestore.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();

  // Canal Android de alta prioridad
  static const _channel = AndroidNotificationChannel(
    'tennis_manager_high',
    'Tennis Manager',
    description: 'Notificaciones importantes de torneos y pedidos',
    importance: Importance.high,
    playSound: true,
  );

  // ── INICIALIZACIÓN (llamar en main() antes de runApp) ──────────────────────
  static Future<void> initialize() async {
    // 1. Handler para mensajes en background/cerrada
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // 2. Pedir permisos (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert:       true,
      badge:       true,
      sound:       true,
      provisional: false,
    );
    debugPrint(
        '🔔 Permisos push: ${settings.authorizationStatus}');

    // 3. Configurar notificaciones locales (para foreground)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotifTap,
    );

    // 4. Crear canal Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 5. Mostrar notificaciones en FOREGROUND como heads-up
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 6. Escuchar mensajes en FOREGROUND
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 7. App abierta desde notificación (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 8. App abierta desde notificación (estaba cerrada)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // 9. Guardar token del dispositivo actual
    await refreshToken();

    // 10. Actualizar token si se renueva
    _messaging.onTokenRefresh.listen(_saveToken);

    debugPrint('✅ PushNotificationService inicializado');
  }

  // ── TOKEN ──────────────────────────────────────────────────────────────────
  static Future<void> refreshToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('⚠️ Error obteniendo FCM token: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Reemplaza el array con solo el token actual para evitar notificaciones
    // duplicadas por tokens viejos de reinstalaciones anteriores.
    await _db.collection('users').doc(uid).update({
      'fcmTokens': [token],
      'fcmToken':  token,
      'lastSeen':  FieldValue.serverTimestamp(),
    });
    debugPrint('💾 FCM token guardado para $uid');
  }

  static Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await _messaging.deleteToken();
    } catch (_) {}
  }

  // ── MANEJO DE MENSAJES ─────────────────────────────────────────────────────
  static void _handleForeground(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    // Mostrar como notificación local heads-up
    _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance:    Importance.high,
          priority:      Priority.high,
          showWhen:      true,
          icon:          '@mipmap/ic_launcher',
          color:         const Color(0xFFCCFF00),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── TAB DESTINO para PlayerHomeScreen al abrir desde notificación ────────
  // 0=perfil, 1=jugar/matchmaking, 2=reservas, 3=torneos, 4=tienda

  /// Callback registrado por PlayerHomeScreen cuando está montado.
  /// Si está registrado se usa directamente (app en background/foreground).
  /// Si es null, se usa pendingHomeTab (app abierta desde cero).
  static void Function(int tab)? onNavigateToTab;
  static int? pendingHomeTab;

  static void _handleTap(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';
    debugPrint('🔔 Notificación tocada: $type — ${message.data}');
    _routeFromType(type);
  }

  static void _onNotifTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type']?.toString() ?? '';
      debugPrint('🔔 Local notif tocada: $data');
      _routeFromType(type);
    } catch (_) {}
  }

  static void _routeFromType(String type) {
    int? tab;
    switch (type) {
      case NotifType.matchRequest:
      case NotifType.matchAccepted:
      case NotifType.matchRejected:
      case NotifType.matchReminder:
      case NotifType.matchCancelled:
        tab = 1; // JUGAR tab
        break;
      case NotifType.matchSlot:
        tab = 2; // RESERVAS tab
        break;
      case NotifType.orderUpdate:
        tab = 4; // TIENDA tab
        break;
      case NotifType.newTournament:
      case NotifType.roundDeadline:
        tab = 3; // TORNEOS tab
        break;
    }
    if (tab == null) return;
    if (onNavigateToTab != null) {
      onNavigateToTab!(tab);
    } else {
      pendingHomeTab = tab;
    }
  }

  // ── ENVÍO DE NOTIFICACIONES ────────────────────────────────────────────────
  // Guarda la notificación en Firestore — Cloud Functions la despacha.
  // Si no hay Cloud Functions, usa el método directo con HTTP.

  /// Enviar notificación a un usuario específico por uid.
  static Future<void> sendToUser({
    required String toUid,
    required String title,
    required String body,
    required String type,
    Map<String, String> extra = const {},
  }) async {
    try {
      // Guardar en cola de notificaciones — Cloud Functions la procesa
      await _db.collection('notification_queue').add({
        'toUid':     toUid,
        'title':     title,
        'body':      body,
        'type':      type,
        'data':      extra,
        'sent':      false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('📤 Notif encolada para $toUid: $title');
    } catch (e) {
      debugPrint('⚠️ Error encolando notificación: $e');
    }
  }

  /// Enviar notificación a todos los jugadores de un club.
  static Future<void> sendToClub({
    required String clubId,
    required String title,
    required String body,
    required String type,
    Map<String, String> extra = const {},
  }) async {
    try {
      await _db.collection('notification_queue').add({
        'toClubId':  clubId,
        'title':     title,
        'body':      body,
        'type':      type,
        'data':      extra,
        'sent':      false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('📤 Notif club $clubId encolada: $title');
    } catch (e) {
      debugPrint('⚠️ Error encolando notificación de club: $e');
    }
  }

  // ── NOTIFICACIONES ESPECÍFICAS DE LA APP ───────────────────────────────────

  /// Turno de torneo asignado — notificar a los dos jugadores
  static Future<void> notifyMatchSlotAssigned({
    required String uid1,
    required String uid2,
    required String player1Name,
    required String player2Name,
    required String courtName,
    required String date,
    required String time,
  }) async {
    await sendToUser(
      toUid: uid1,
      title: '🎾 Turno asignado',
      body:  'Tu partido contra $player2Name es el $date a las $time en $courtName.',
      type:  NotifType.matchSlot,
      extra: {'date': date, 'time': time, 'court': courtName},
    );
    await sendToUser(
      toUid: uid2,
      title: '🎾 Turno asignado',
      body:  'Tu partido contra $player1Name es el $date a las $time en $courtName.',
      type:  NotifType.matchSlot,
      extra: {'date': date, 'time': time, 'court': courtName},
    );
  }

  /// Pedido de tienda actualizado — notificar al comprador
  static Future<void> notifyOrderUpdate({
    required String buyerUid,
    required String status,
    required String clubName,
  }) async {
    String title, body;
    switch (status) {
      case 'confirmed':
        title = '✅ Pedido confirmado';
        body  = '$clubName confirmó tu pedido. Lo están preparando.';
        break;
      case 'ready':
        title = '🎾 Pedido listo';
        body  = '¡Tu pedido en $clubName está listo para retirar!';
        break;
      case 'delivered':
        title = '🏆 Pedido entregado';
        body  = 'Tu pedido fue entregado. ¡Disfrutalo!';
        break;
      case 'cancelled':
        title = '❌ Pedido cancelado';
        body  = 'Tu pedido en $clubName fue cancelado.';
        break;
      default:
        return;
    }
    await sendToUser(
      toUid: buyerUid,
      title: title,
      body:  body,
      type:  NotifType.orderUpdate,
      extra: {'status': status},
    );
  }

  /// Solicitud de partido recibida — notificar al desafiado
  static Future<void> notifyMatchRequest({
    required String toUid,
    required String fromName,
    required String timeSlot,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '🎾 ¡Te desafían!',
      body:  '$fromName quiere jugar contra vos en el horario $timeSlot.',
      type:  NotifType.matchRequest,
      extra: {'fromName': fromName, 'timeSlot': timeSlot},
    );
  }

  /// Nuevo torneo creado en el club — notificar a todos los jugadores
  static Future<void> notifyNewTournament({
    required String clubId,
    required String tournamentName,
    required String category,
  }) async {
    await sendToClub(
      clubId:  clubId,
      title:   '🏆 Nuevo torneo disponible',
      body:    '$tournamentName — $category. ¡Inscribite ahora!',
      type:    NotifType.newTournament,
      extra:   {'tournamentName': tournamentName, 'category': category},
    );
  }

  /// Propuesta de partido aceptada — notificar al que propuso
  static Future<void> notifyMatchAccepted({
    required String toUid,
    required String fromName,
    required String date,
    required String timeSlot,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '✅ ¡Partido coordinado!',
      body:  '$fromName aceptó jugar el $date, horario $timeSlot.',
      type:  NotifType.matchAccepted,
      extra: {'fromName': fromName, 'date': date, 'timeSlot': timeSlot},
    );
  }

  /// Propuesta de partido rechazada — notificar al que propuso
  static Future<void> notifyMatchRejected({
    required String toUid,
    required String fromName,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '❌ Propuesta rechazada',
      body:  '$fromName no puede jugar en ese horario.',
      type:  NotifType.matchRejected,
      extra: {'fromName': fromName},
    );
  }

  /// Partido cancelado — notificar al rival
  static Future<void> notifyMatchCancelled({
    required String toUid,
    required String fromName,
    required String date,
    required String timeSlot,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '❌ Partido cancelado',
      body:  '$fromName canceló el partido del $date a las $timeSlot.',
      type:  NotifType.matchCancelled,
      extra: {'fromName': fromName, 'date': date, 'timeSlot': timeSlot},
    );
  }

  /// Reserva de cancha cancelada — notificar al jugador (para auto-aviso)
  static Future<void> notifyBookingCancelled({
    required String toUid,
    required String courtName,
    required String date,
    required String startTime,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '🎾 Reserva cancelada',
      body:  'Tu reserva en $courtName el $date a las $startTime fue cancelada.',
      type:  NotifType.orderUpdate,
      extra: {'courtName': courtName, 'date': date, 'time': startTime},
    );
  }

  /// Recordatorio de partido próximo
  static Future<void> notifyMatchReminder({
    required String toUid,
    required String opponentName,
    required String timeLabel, // '2 horas' o '30 minutos'
    required String timeSlot,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '⏰ Partido en $timeLabel',
      body:  'Tu partido contra $opponentName es a las $timeSlot.',
      type:  NotifType.matchReminder,
      extra: {'opponentName': opponentName, 'timeSlot': timeSlot},
    );
  }

  /// Ronda de torneo por vencer — recordatorio
  static Future<void> notifyRoundDeadline({
    required String uid1,
    required String uid2,
    required String player1Name,
    required String player2Name,
    required String roundLabel,
    required String deadline,
  }) async {
    await sendToUser(
      toUid: uid1,
      title: '⚠️ Ronda por vencer',
      body:  'Tu partido de $roundLabel contra $player2Name vence el $deadline.',
      type:  NotifType.roundDeadline,
      extra: {'round': roundLabel, 'deadline': deadline},
    );
    await sendToUser(
      toUid: uid2,
      title: '⚠️ Ronda por vencer',
      body:  'Tu partido de $roundLabel contra $player1Name vence el $deadline.',
      type:  NotifType.roundDeadline,
      extra: {'round': roundLabel, 'deadline': deadline},
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVIGATOR KEY GLOBAL — para routing desde notificaciones
// Declarar en main.dart: final navigatorKey = GlobalKey<NavigatorState>();
// ─────────────────────────────────────────────────────────────────────────────
// Uso en main.dart:
//   MaterialApp(navigatorKey: navigatorKey, ...)
// Uso en PushNotificationService._handleTap:
//   navigatorKey.currentState?.pushNamed('/orders');
