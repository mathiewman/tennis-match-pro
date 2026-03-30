import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Escribe novedades en clubs/{clubId}/notifications.
/// Llamar desde cualquier parte de la app.
class NotificationService {
  static Future<void> write({
    required String clubId,
    required String type,
    required String message,
    Map<String, dynamic> extra = const {},
  }) async {
    if (clubId.isEmpty) return;
    final now     = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);
    final sortKey = DateFormat('yyyyMMddHHmm').format(now);
    try {
      await FirebaseFirestore.instance
          .collection('clubs').doc(clubId)
          .collection('notifications')
          .add({
        'type':      type,
        'message':   message,
        'date':      dateStr,
        'time':      timeStr,
        'sortKey':   sortKey,
        'createdAt': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (_) {}
  }
}
