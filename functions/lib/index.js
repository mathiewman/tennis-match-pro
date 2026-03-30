"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendMatchReminders = exports.cleanNotificationQueue = exports.processNotificationQueue = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// ─────────────────────────────────────────────────────────────────────────────
// PROCESAR COLA DE NOTIFICACIONES
// Se dispara cuando se crea un nuevo documento en notification_queue
// ─────────────────────────────────────────────────────────────────────────────
exports.processNotificationQueue = functions
    .region("us-central1")
    .firestore.document("notification_queue/{docId}")
    .onCreate(async (snap) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const data = snap.data();
    if (!data || data["sent"] === true)
        return;
    const title = (_a = data["title"]) !== null && _a !== void 0 ? _a : "";
    const body = (_b = data["body"]) !== null && _b !== void 0 ? _b : "";
    const type = (_c = data["type"]) !== null && _c !== void 0 ? _c : "";
    const extraData = (_d = data["data"]) !== null && _d !== void 0 ? _d : {};
    const tokens = [];
    try {
        if (data["toUid"]) {
            // Notificación a un usuario específico
            const userDoc = await db.collection("users").doc(data["toUid"]).get();
            const fcmTokens = (_f = (_e = userDoc.data()) === null || _e === void 0 ? void 0 : _e["fcmTokens"]) !== null && _f !== void 0 ? _f : [];
            tokens.push(...fcmTokens);
        }
        else if (data["toClubId"]) {
            // Notificación a todos los jugadores del club
            const usersSnap = await db
                .collection("users")
                .where("homeClubId", "==", data["toClubId"])
                .get();
            for (const userDoc of usersSnap.docs) {
                const fcmTokens = (_g = userDoc.data()["fcmTokens"]) !== null && _g !== void 0 ? _g : [];
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
        const invalidTokens = [];
        for (let i = 0; i < uniqueTokens.length; i += 500) {
            const batch = uniqueTokens.slice(i, i + 500);
            const message = {
                tokens: batch,
                notification: { title, body },
                data: Object.assign({ type }, extraData),
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
                var _a, _b;
                if (!resp.success) {
                    const code = (_b = (_a = resp.error) === null || _a === void 0 ? void 0 : _a.code) !== null && _b !== void 0 ? _b : "";
                    if (code === "messaging/invalid-registration-token" ||
                        code === "messaging/registration-token-not-registered") {
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
                const current = (_h = userDoc.data()["fcmTokens"]) !== null && _h !== void 0 ? _h : [];
                const cleaned = current.filter((t) => !invalidTokens.includes(t));
                await userDoc.ref.update({ fcmTokens: cleaned });
            }
        }
        await snap.ref.update({
            sent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (err) {
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
exports.cleanNotificationQueue = functions
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
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r;
    const now = new Date();
    // Ventana de 2 horas: [now+1.75h, now+2.25h]
    const win2hStart = new Date(now.getTime() + 1.75 * 60 * 60 * 1000);
    const win2hEnd = new Date(now.getTime() + 2.25 * 60 * 60 * 1000);
    // Ventana de 30 minutos: [now+15min, now+45min]
    const win30Start = new Date(now.getTime() + 15 * 60 * 1000);
    const win30End = new Date(now.getTime() + 45 * 60 * 1000);
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
            body: `Tu partido contra ${m["player2Name"]} es a las ${(_b = (_a = m["timeSlot"]) === null || _a === void 0 ? void 0 : _a.split(" - ")[0]) !== null && _b !== void 0 ? _b : ""}`,
            type: "match_reminder",
            data: { opponentName: (_c = m["player2Name"]) !== null && _c !== void 0 ? _c : "", timeSlot: (_d = m["timeSlot"]) !== null && _d !== void 0 ? _d : "" },
            sent: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await db.collection("notification_queue").add({
            toUid: m["player2Uid"],
            title: "⏰ Partido en 2 horas",
            body: `Tu partido contra ${m["player1Name"]} es a las ${(_f = (_e = m["timeSlot"]) === null || _e === void 0 ? void 0 : _e.split(" - ")[0]) !== null && _f !== void 0 ? _f : ""}`,
            type: "match_reminder",
            data: { opponentName: (_g = m["player1Name"]) !== null && _g !== void 0 ? _g : "", timeSlot: (_h = m["timeSlot"]) !== null && _h !== void 0 ? _h : "" },
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
            body: `Tu partido contra ${m["player2Name"]} es a las ${(_k = (_j = m["timeSlot"]) === null || _j === void 0 ? void 0 : _j.split(" - ")[0]) !== null && _k !== void 0 ? _k : ""}`,
            type: "match_reminder",
            data: { opponentName: (_l = m["player2Name"]) !== null && _l !== void 0 ? _l : "", timeSlot: (_m = m["timeSlot"]) !== null && _m !== void 0 ? _m : "" },
            sent: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await db.collection("notification_queue").add({
            toUid: m["player2Uid"],
            title: "⏰ Partido en 30 minutos",
            body: `Tu partido contra ${m["player1Name"]} es a las ${(_p = (_o = m["timeSlot"]) === null || _o === void 0 ? void 0 : _o.split(" - ")[0]) !== null && _p !== void 0 ? _p : ""}`,
            type: "match_reminder",
            data: { opponentName: (_q = m["player1Name"]) !== null && _q !== void 0 ? _q : "", timeSlot: (_r = m["timeSlot"]) !== null && _r !== void 0 ? _r : "" },
            sent: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await doc.ref.update({ reminder30mSent: true });
    }
    functions.logger.log(`Reminders sent: ${snap2h.docs.length} × 2h, ${snap30.docs.length} × 30min`);
}
exports.sendMatchReminders = functions
    .region("us-central1")
    .pubsub.schedule("every 15 minutes")
    .onRun(async () => {
    await sendMatchRemindersImpl();
});
//# sourceMappingURL=index.js.map