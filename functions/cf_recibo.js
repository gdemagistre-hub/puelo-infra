const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { admin, db, crypto, requireAuthUid } = require("./cf_shared");

const RECIBO_CONCEPTOS = new Set(["sena", "anticipo", "saldo", "pago_total", "otro"]);

function reciboHmacSecret() {
  const secret = String(process.env.RECIBO_HMAC_SECRET || "").trim();
  if (!secret) {
    throw new HttpsError("unavailable", "Firma de comprobante no disponible");
  }
  return secret;
}

function canonicalReciboPayload(p) {
  return JSON.stringify({
    tipo: p.tipo,
    conversacion_id: p.conversacion_id,
    actor_uid: p.actor_uid,
    contraparte_uid: p.contraparte_uid,
    monto: p.monto,
    moneda: p.moneda,
    concepto: p.concepto,
    nota: p.nota || "",
    recibo_event_id: p.recibo_event_id || null,
    decision: p.decision || null,
    motivo: p.motivo || "",
    created_at_iso: p.created_at_iso,
  });
}

function hashContenido(payloadObj) {
  return crypto
    .createHmac("sha256", reciboHmacSecret())
    .update(canonicalReciboPayload(payloadObj))
    .digest("hex");
}

function conversacionIdFor(uidA, uidB) {
  const a = String(uidA);
  const b = String(uidB);
  return a < b ? `${a}__${b}` : `${b}__${a}`;
}

function parseMonto(raw) {
  const n = typeof raw === "number" ? raw : Number(String(raw).replace(",", "."));
  if (!Number.isFinite(n) || n <= 0 || n > 999999999) return null;
  return Math.round(n * 100) / 100;
}

exports.emitirRecibo = onCall(
  { cors: true, memory: "256MiB", timeoutSeconds: 30, secrets: ["RECIBO_HMAC_SECRET"] },
  async (request) => {
    const actorUid = requireAuthUid(request);
    const d = request.data || {};
    const contraparte = String(d.contraparte_uid || "").trim();
    if (!contraparte || contraparte === actorUid) {
      throw new HttpsError("invalid-argument", "contraparte_uid inválido");
    }
    const monto = parseMonto(d.monto);
    if (monto == null) {
      throw new HttpsError("invalid-argument", "monto inválido");
    }
    const concepto = String(d.concepto || "otro").trim().toLowerCase();
    if (!RECIBO_CONCEPTOS.has(concepto)) {
      throw new HttpsError("invalid-argument", "concepto inválido");
    }
    const nota = String(d.nota || "").trim().slice(0, 200);
    const origen = String(d.origen || "manual").trim().slice(0, 40);
    const convId = conversacionIdFor(actorUid, contraparte);
    const convRef = db.collection("conversaciones").doc(convId);
    const convSnap = await convRef.get();
    if (convSnap.exists) {
      const pending = convSnap.get("pending_recibo_event_id");
      if (pending) {
        throw new HttpsError(
          "failed-precondition",
          "Ya hay un comprobante pendiente en este hilo. Esperá la confirmación o que se resuelva."
        );
      }
    }
    const createdAtIso = new Date().toISOString();
    const eventRef = convRef.collection("eventos").doc();
    const eventId = eventRef.id;
    const hashInput = {
      tipo: "recibo_emitido",
      conversacion_id: convId,
      actor_uid: actorUid,
      contraparte_uid: contraparte,
      monto,
      moneda: "ARS",
      concepto,
      nota,
      recibo_event_id: null,
      decision: null,
      motivo: "",
      created_at_iso: createdAtIso,
    };
    const contentHash = hashContenido(hashInput);
    const eventDoc = {
      tipo: "recibo_emitido",
      actor_uid: actorUid,
      contraparte_uid: contraparte,
      monto,
      moneda: "ARS",
      concepto,
      nota,
      estado: "pendiente",
      content_hash: contentHash,
      hash_v: 1,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at_iso: createdAtIso,
    };
    const participantes = [actorUid, contraparte].sort();
    const batch = db.batch();
    if (!convSnap.exists) {
      batch.set(convRef, {
        participantes,
        cliente_uid: actorUid,
        prestador_uid: contraparte,
        origen,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        last_summary: `Pago $${monto} · Pendiente`,
        last_event_at: admin.firestore.FieldValue.serverTimestamp(),
        pending_recibo_event_id: eventId,
        pending_recibo_actor_uid: actorUid,
      });
    } else {
      batch.update(convRef, {
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        last_summary: `Pago $${monto} · Pendiente`,
        last_event_at: admin.firestore.FieldValue.serverTimestamp(),
        pending_recibo_event_id: eventId,
        pending_recibo_actor_uid: actorUid,
      });
    }
    batch.set(eventRef, eventDoc);
    await batch.commit();
    return {
      ok: true,
      conversacion_id: convId,
      event_id: eventId,
      content_hash: contentHash,
      estado: "pendiente",
      monto,
      concepto,
    };
  }
);

exports.responderRecibo = onCall(
  { cors: true, memory: "256MiB", timeoutSeconds: 30, secrets: ["RECIBO_HMAC_SECRET"] },
  async (request) => {
    const actorUid = requireAuthUid(request);
    const d = request.data || {};
    const convId = String(d.conversacion_id || "").trim();
    const reciboEventId = String(d.recibo_event_id || "").trim();
    const decision = String(d.decision || "").trim().toLowerCase();
    const motivo = String(d.motivo || "").trim().slice(0, 200);
    if (!convId || !reciboEventId) {
      throw new HttpsError("invalid-argument", "ids requeridos");
    }
    if (decision !== "aceptado" && decision !== "rechazado") {
      throw new HttpsError("invalid-argument", "decision inválida");
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
    const reciboRef = convRef.collection("eventos").doc(reciboEventId);
    const reciboSnap = await reciboRef.get();
    if (!reciboSnap.exists) {
      throw new HttpsError("not-found", "Comprobante no encontrado");
    }
    const recibo = reciboSnap.data() || {};
    if (recibo.tipo !== "recibo_emitido") {
      throw new HttpsError("failed-precondition", "No es un comprobante de pago");
    }
    if (recibo.actor_uid === actorUid) {
      throw new HttpsError("failed-precondition", "No podés confirmar tu propio comprobante");
    }
    if (conv.pending_recibo_event_id !== reciboEventId) {
      throw new HttpsError(
        "failed-precondition",
        "Este comprobante ya no está pendiente (fue confirmado o no es el activo)"
      );
    }
    const createdAtIso = new Date().toISOString();
    const respRef = convRef.collection("eventos").doc();
    const hashInput = {
      tipo: decision === "aceptado" ? "recibo_aceptado" : "recibo_rechazado",
      conversacion_id: convId,
      actor_uid: actorUid,
      contraparte_uid: recibo.actor_uid,
      monto: recibo.monto,
      moneda: recibo.moneda || "ARS",
      concepto: recibo.concepto || "",
      nota: "",
      recibo_event_id: reciboEventId,
      decision,
      motivo: decision === "rechazado" ? motivo : "",
      created_at_iso: createdAtIso,
    };
    const contentHash = hashContenido(hashInput);
    const respDoc = {
      tipo: hashInput.tipo,
      actor_uid: actorUid,
      recibo_event_id: reciboEventId,
      decision,
      motivo: decision === "rechazado" ? motivo : "",
      monto: recibo.monto,
      moneda: recibo.moneda || "ARS",
      concepto: recibo.concepto || "",
      content_hash: contentHash,
      hash_v: 1,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at_iso: createdAtIso,
    };
    const label =
      decision === "aceptado"
        ? `Pago $${recibo.monto} · Aceptado`
        : `Pago $${recibo.monto} · Rechazado`;
    const batch = db.batch();
    batch.set(respRef, respDoc);
    batch.update(convRef, {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      last_summary: label,
      last_event_at: admin.firestore.FieldValue.serverTimestamp(),
      pending_recibo_event_id: admin.firestore.FieldValue.delete(),
      pending_recibo_actor_uid: admin.firestore.FieldValue.delete(),
      last_recibo_decision: decision,
      last_recibo_event_id: reciboEventId,
      last_respuesta_event_id: respRef.id,
    });
    await batch.commit();
    return {
      ok: true,
      conversacion_id: convId,
      recibo_event_id: reciboEventId,
      respuesta_event_id: respRef.id,
      decision,
      content_hash: contentHash,
    };
  }
);
