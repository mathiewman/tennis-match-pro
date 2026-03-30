import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// PROCESAR COLA DE NOTIFICACIONES
// Se dispara cuando se crea un nuevo documento en notification_queue
// ─────────────────────────────────────────────────────────────────────────────
export const processNotificationQueue = functions
  .region("us-central1")
  .firestore.document("notification_queue/{docId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    if (!data || data["sent"] === true) return;

    const title: string = data["title"] ?? "";
    const body: string = data["body"] ?? "";
    const type: string = data["type"] ?? "";
    const extraData: Record<string, string> = data["data"] ?? {};

    const tokens: string[] = [];

    try {
      if (data["toUid"]) {
        // Notificación a un usuario específico
        const userDoc = await db.collection("users").doc(data["toUid"]).get();
        const fcmTokens: string[] = userDoc.data()?.["fcmTokens"] ?? [];
        tokens.push(...fcmTokens);
      } else if (data["toClubId"]) {
        // Notificación a todos los jugadores del club
        const usersSnap = await db
          .collection("users")
          .where("homeClubId", "==", data["toClubId"])
          .get();
        for (const userDoc of usersSnap.docs) {
          const fcmTokens: string[] = userDoc.data()["fcmTokens"] ?? [];
          tokens.push(...fcmTokens);
        }
      }

      if (tokens.length === 0) {
        await snap.ref.update({
          sent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          error: "no_tokens",
        });
        return;
      }

      // Eliminar tokens duplicados
      const uniqueTokens = [...new Set(tokens)];

      // Enviar en lotes de 500
      const invalidTokens: string[] = [];
      for (let i = 0; i < uniqueTokens.length; i += 500) {
        const batch = uniqueTokens.slice(i, i + 500);

        const message: admin.messaging.MulticastMessage = {
          tokens: batch,
          notification: { title, body },
          data: { type, ...extraData },
          android: {
            priority: "high",
            notification: {
              channelId: "tennis_match_pro",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: { sound: "default", badge: 1 },
            },
          },
        };

        const response = await messaging.sendEachForMulticast(message);
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const code = resp.error?.code ?? "";
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(batch[idx]);
            }
          }
        });
      }

      // Limpiar tokens inválidos de usuarios
      if (invalidTokens.length > 0) {
        const usersWithBadTokens = await db
          .collection("users")
          .where("fcmTokens", "array-contains-any", invalidTokens.slice(0, 10))
          .get();
        for (const userDoc of usersWithBadTokens.docs) {
          const current: string[] = userDoc.data()["fcmTokens"] ?? [];
          const cleaned = current.filter((t) => !invalidTokens.includes(t));
          await userDoc.ref.update({ fcmTokens: cleaned });
        }
      }

      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      functions.logger.error("Error processing notification:", err);
      await snap.ref.update({
        sent: false,
        error: String(err),
        retryAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

// ─────────────────────────────────────────────────────────────────────────────
// LIMPIAR COLA ANTIGUA (ejecuta diariamente a las 3am UTC)
// ─────────────────────────────────────────────────────────────────────────────
export const cleanNotificationQueue = functions
  .region("us-central1")
  .pubsub.schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 7); // 7 días atrás

    const old = await db
      .collection("notification_queue")
      .where("sent", "==", true)
      .where("sentAt", "<", cutoff)
      .limit(500)
      .get();

    const batch = db.batch();
    old.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    functions.logger.log(`Cleaned ${old.docs.length} old notifications`);
  });

// ─────────────────────────────────────────────────────────────────────────────
// RECORDATORIOS DE PARTIDO — ejecuta cada 15 minutos
// Envía recordatorio 2h antes y 30min antes del partido
// ─────────────────────────────────────────────────────────────────────────────
async function sendMatchRemindersImpl() {
  const now = new Date();

  // Ventana de 2 horas: [now+1.75h, now+2.25h]
  const win2hStart = new Date(now.getTime() + 1.75 * 60 * 60 * 1000);
  const win2hEnd   = new Date(now.getTime() + 2.25 * 60 * 60 * 1000);

  // Ventana de 30 minutos: [now+15min, now+45min]
  const win30Start = new Date(now.getTime() + 15 * 60 * 1000);
  const win30End   = new Date(now.getTime() + 45 * 60 * 1000);

  // Consulta para recordatorio de 2 horas
  const snap2h = await db
    .collection("scheduled_matches")
    .where("scheduledAt", ">=", win2hStart)
    .where("scheduledAt", "<=", win2hEnd)
    .where("reminder2hSent", "==", false)
    .get();

  for (const doc of snap2h.docs) {
    const m = doc.data();
    await db.collection("notification_queue").add({
      toUid: m["player1Uid"],
      title: "⏰ Partido en 2 horas",
      body: `Tu partido contra ${m["player2Name"]} es a las ${m["timeSlot"]?.split(" - ")[0] ?? ""}`,
      type: "match_reminder",
      data: { opponentName: m["player2Name"] ?? "", timeSlot: m["timeSlot"] ?? "" },
      sent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection("notification_queue").add({
      toUid: m["player2Uid"],
      title: "⏰ Partido en 2 horas",
      body: `Tu partido contra ${m["player1Name"]} es a las ${m["timeSlot"]?.split(" - ")[0] ?? ""}`,
      type: "match_reminder",
      data: { opponentName: m["player1Name"] ?? "", timeSlot: m["timeSlot"] ?? "" },
      sent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await doc.ref.update({ reminder2hSent: true });
  }

  // Consulta para recordatorio de 30 minutos
  const snap30 = await db
    .collection("scheduled_matches")
    .where("scheduledAt", ">=", win30Start)
    .where("scheduledAt", "<=", win30End)
    .where("reminder30mSent", "==", false)
    .get();

  for (const doc of snap30.docs) {
    const m = doc.data();
    await db.collection("notification_queue").add({
      toUid: m["player1Uid"],
      title: "⏰ Partido en 30 minutos",
      body: `Tu partido contra ${m["player2Name"]} es a las ${m["timeSlot"]?.split(" - ")[0] ?? ""}`,
      type: "match_reminder",
      data: { opponentName: m["player2Name"] ?? "", timeSlot: m["timeSlot"] ?? "" },
      sent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection("notification_queue").add({
      toUid: m["player2Uid"],
      title: "⏰ Partido en 30 minutos",
      body: `Tu partido contra ${m["player1Name"]} es a las ${m["timeSlot"]?.split(" - ")[0] ?? ""}`,
      type: "match_reminder",
      data: { opponentName: m["player1Name"] ?? "", timeSlot: m["timeSlot"] ?? "" },
      sent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await doc.ref.update({ reminder30mSent: true });
  }

  functions.logger.log(
    `Reminders sent: ${snap2h.docs.length} × 2h, ${snap30.docs.length} × 30min`
  );
}

export const sendMatchReminders = functions
  .region("us-central1")
  .pubsub.schedule("every 15 minutes")
  .onRun(async () => {
    await sendMatchRemindersImpl();
  });
