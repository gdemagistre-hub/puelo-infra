/**
 * Mensajes M5 — texto libre append-only en conversaciones.
 * Se monta desde index.js: exports.enviarMensajeTexto = ...
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

const db = admin.firestore();

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
}

function textoHmacSecret() {
  return (
    process.env.RECIBO_HMAC_SECRET ||
    process.env.VAULT_RECOVERY_SECRET ||
    "lifewalletpuelo-recibo-hmac-v1"
  );
}

function hashTexto(payload) {
  const body = JSON.stringify({
    tipo: "mensaje_texto",
    conversacion_id: payload.conversacion_id,
    actor_uid: payload.actor_uid,
    texto: payload.texto,
    created_at_iso: payload.created_at_iso,
  });
  return crypto.createHmac("sha256", textoHmacSecret()).update(body).digest("hex");
}

exports.enviarMensajeTexto = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 30,
    region: "us-east1",
  },
  async (request) => {
    const actorUid = requireAuthUid(request);
    const d = request.data || {};
    const convId = String(d.conversacion_id || "").trim();
    const texto = String(d.texto || "").trim().slice(0, 500);

    if (!convId) {
      throw new HttpsError("invalid-argument", "conversacion_id requerido");
    }
    if (!texto) {
      throw new HttpsError("invalid-argument", "Escribí un mensaje");
    }

    const convRef = db.collection("conversaciones").doc(convId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
      throw new HttpsError("not-found", "Conversación no encontrada");
    }
    const conv = convSnap.data() || {};
    const partes = conv.participantes || [];
    if (!partes.includes(actorUid)) {
      throw new HttpsError("permission-denied", "No sos parte de este hilo");
    }

    const createdAtIso = new Date().toISOString();
    const eventRef = convRef.collection("eventos").doc();
    const contentHash = hashTexto({
      conversacion_id: convId,
      actor_uid: actorUid,
      texto,
      created_at_iso: createdAtIso,
    });

    const summary =
      texto.length > 48 ? `${texto.slice(0, 45)}…` : texto;

    const batch = db.batch();
    batch.set(eventRef, {
      tipo: "mensaje_texto",
      actor_uid: actorUid,
      texto,
      content_hash: contentHash,
      hash_v: 1,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at_iso: createdAtIso,
    });
    batch.update(convRef, {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      last_summary: summary,
      last_event_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return {
      ok: true,
      conversacion_id: convId,
      event_id: eventRef.id,
      content_hash: contentHash,
    };
  }
);
