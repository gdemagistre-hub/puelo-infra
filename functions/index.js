/**
 * Cloud Functions — Puelo (lifewalletpuelo)
 * Scoring, validación domicilio, vault recovery (Mis números), mensajes recibos.
 * 2026-08-20: aviso calificación prestador (push + inbox).
 * 2026-08-24: mintDevSession eliminado (impersonación).
 */
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { runScoringBatch, runTopServiciosAyer } = require("./scoringCore");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

setGlobalOptions({
  region: "us-east1",
  memory: "1GiB",
  timeoutSeconds: 540,
});

function timingSafeEqualString(a, b) {
  const left = crypto.createHash("sha256").update(String(a ?? ""), "utf8").digest();
  const right = crypto.createHash("sha256").update(String(b ?? ""), "utf8").digest();
  return crypto.timingSafeEqual(left, right);
}

const ALLOWED_ORIGINS = [
  "https://lifewalletpuelo.web.app",
  "https://lifewalletpuelo.firebaseapp.com",
  "https://walletpuelo.web.app",
  "https://walletpuelo.firebaseapp.com",
  "http://localhost:5000",
  "http://localhost:8080",
  "http://127.0.0.1:5000",
  "http://127.0.0.1:8080",
];

function applyCors(req, res) {
  const origin = req.get("Origin") || "";
  if (ALLOWED_ORIGINS.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  } else if (!origin) {
    res.set("Access-Control-Allow-Origin", ALLOWED_ORIGINS[0]);
  }
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization, X-Batch-Secret"
  );
}

async function verifyBearer(req) {
  const h = req.get("Authorization") || "";
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  return admin.auth().verifyIdToken(m[1]);
}

function envFlag(name, defaultValue = "0") {
  const v = process.env[name];
  if (v === undefined || v === null || v === "") return defaultValue;
  return String(v);
}

exports.scoringBatchHttp = onRequest(
  {
    invoker: "public",
    secrets: ["BATCH_SECRET"],
  },
  async (req, res) => {
    applyCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST" && req.method !== "GET") {
      res.status(405).send("Method not allowed");
      return;
    }
    const secret = process.env.BATCH_SECRET || "";
    const provided =
      req.get("X-Batch-Secret") ||
      req.query.secret ||
      (req.body && req.body.secret) ||
      "";
    if (!secret) {
      res.status(503).json({ error: "batch_secret_not_configured" });
      return;
    }
    if (!timingSafeEqualString(provided, secret)) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }
    const force = req.query.force === "1" || (req.body && req.body.force === true);
    const trigger = req.query.trigger || (req.body && req.body.trigger) || "http";
    try {
      const result = await runScoringBatch({ trigger, force });
      res.status(200).json(result);
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);

exports.scoringBatchDaily = onSchedule(
  {
    schedule: "30 2 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    let top = { status: "skipped" };
    try {
      top = await runTopServiciosAyer();
      console.log("topServiciosAyer", top);
    } catch (e) {
      console.error("topServiciosAyer", e);
    }
    const result = await runScoringBatch({ trigger: "scheduler" });
    console.log("scoringBatchDaily", result);
    return { scoring: result, topServicios: top };
  }
);

exports.submitValidacionPendiente = onRequest(
  { invoker: "public", cors: ALLOWED_ORIGINS, memory: "256MiB", timeoutSeconds: 60 },
  async (req, res) => {
    applyCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }
    try {
      const b = req.body || {};
      const targetUserId = String(b.targetUserId || "").trim();
      if (!targetUserId) {
        res.status(400).json({ error: "targetUserId_required" });
        return;
      }
      const token = String(b.token || "").trim() || db.collection("_").doc().id;
      const doc = {
        tipo: "validacion_pendiente",
        targetUserId,
        targetNombre: String(b.targetNombre || "").slice(0, 120),
        conoce: !!b.conoce,
        domicilioSeleccionado: String(b.domicilioSeleccionado || "").slice(0, 300),
        domicilioReal: String(b.domicilioReal || "").slice(0, 300),
        esCorrecto: !!b.esCorrecto,
        tiempoViviendo: String(b.tiempoViviendo || "").slice(0, 80),
        estado: "pendiente",
        creado_en: admin.firestore.FieldValue.serverTimestamp(),
        fuente: "cloud_function",
      };
      const batch = db.batch();
      batch.set(db.collection("validaciones").doc(token), doc);
      batch.set(db.collection("validaciones_pendientes").doc(token), doc);
      batch.set(db.collection("calificaciones").doc(token), doc);
      await batch.commit();
      res.status(200).json({ ok: true, token });
    } catch (e) {
      console.error("submitValidacionPendiente", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);

exports.aplicarValidacionPendiente = onRequest(
  {
    invoker: "public",
    cors: ALLOWED_ORIGINS,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
    applyCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }
    try {
      const b = req.body || {};
      const token = String(b.token || "").trim();
      if (!token) {
        res.status(400).json({ error: "token_required" });
        return;
      }
      let validadorId = "";
      let via = "none";
      try {
        const decoded = await verifyBearer(req);
        if (decoded && decoded.uid) {
          validadorId = decoded.uid;
          via = "auth";
        }
      } catch (authErr) {
        console.warn("aplicarValidacion token invalid", authErr.message || authErr);
      }
      if (!validadorId) {
        const allowDev = envFlag("ALLOW_DEV_VALIDACION", "1") === "1";
        const bodyId = String(b.validadorId || "").trim();
        if (allowDev && bodyId) {
          validadorId = bodyId;
          via = "dev_impersonation";
          console.warn("aplicarValidacionPendiente via dev_impersonation", bodyId);
        } else {
          res.status(401).json({ error: "unauthenticated" });
          return;
        }
      }
      let pendRef = db.collection("validaciones").doc(token);
      let pendSnap = await pendRef.get();
      if (!pendSnap.exists) {
        pendRef = db.collection("validaciones_pendientes").doc(token);
        pendSnap = await pendRef.get();
      }
      if (!pendSnap.exists) {
        pendRef = db.collection("calificaciones").doc(token);
        pendSnap = await pendRef.get();
      }
      if (!pendSnap.exists) {
        res.status(404).json({ error: "pendiente_not_found" });
        return;
      }
      const pend = pendSnap.data() || {};
      if (pend.estado !== "pendiente") {
        res.status(200).json({ ok: true, already: true, estado: pend.estado, via });
        return;
      }
      const targetUserId = String(pend.targetUserId || "").trim();
      if (!targetUserId) {
        res.status(400).json({ error: "target_missing" });
        return;
      }
      if (targetUserId === validadorId) {
        res.status(400).json({ error: "no_self_validate" });
        return;
      }
      const valSnap = await db.collection("usuarios").doc(validadorId).get();
      const valData = valSnap.data() || {};
      const recibidas = (valData.validaciones_recibidas || []).length;
      const emitidas =
        Number(valData.validaciones_emitidas_count || 0) ||
        (valData.validaciones_emitidas || []).length ||
        0;
      let ultimaDt = null;
      const ultima = valData.ultima_validacion_emitida_en;
      if (ultima && ultima.toDate) ultimaDt = ultima.toDate();
      else if (typeof ultima === "string") ultimaDt = new Date(ultima);
      if (recibidas === 0 && emitidas >= 1) {
        await pendRef.update({
          tipo: "validacion_aplicada",
          estado: "rechazado_limite",
          motivo_rechazo:
            "Para validar a otra persona, primero alguien tiene que validarte a vos.",
          procesado_en: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(403).json({
          error: "limit",
          reason:
            "Para validar a otra persona, primero alguien tiene que validarte a vos.",
        });
        return;
      }
      if (recibidas > 0 && emitidas >= 1 && ultimaDt) {
        const dias = (Date.now() - ultimaDt.getTime()) / (24 * 3600 * 1000);
        if (dias < 7) {
          const reason = `Podés volver a validar a alguien en ${Math.ceil(7 - dias)} día(s).`;
          await pendRef.update({
            tipo: "validacion_aplicada",
            estado: "rechazado_limite",
            motivo_rechazo: reason,
            procesado_en: admin.firestore.FieldValue.serverTimestamp(),
          });
          res.status(403).json({ error: "limit", reason });
          return;
        }
      }
      const registro = {
        validadorId,
        validador_id: validadorId,
        conoce: !!pend.conoce,
        domicilioSeleccionado: pend.domicilioSeleccionado || "",
        esCorrecto: !!pend.esCorrecto,
        tiempoViviendo: pend.tiempoViviendo || "",
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        tipo: "identidad",
        via,
      };
      const batch = db.batch();
      batch.update(pendRef, {
        tipo: "validacion_aplicada",
        validadorId,
        estado: "completado",
        procesado_en: admin.firestore.FieldValue.serverTimestamp(),
        via,
      });
      batch.update(db.collection("usuarios").doc(targetUserId), {
        validaciones_recibidas: admin.firestore.FieldValue.arrayUnion(registro),
      });
      batch.update(db.collection("usuarios").doc(validadorId), {
        validaciones_emitidas_count: admin.firestore.FieldValue.increment(1),
        validaciones_emitidas: admin.firestore.FieldValue.arrayUnion([
          {
            target_id: targetUserId,
            token,
            fecha: new Date().toISOString(),
          },
        ]),
        ultima_validacion_emitida_en: admin.firestore.FieldValue.serverTimestamp(),
      });
      await batch.commit();
      res.status(200).json({
        ok: true,
        targetUserId,
        targetNombre: pend.targetNombre || "",
        via,
      });
    } catch (e) {
      console.error("aplicarValidacionPendiente", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);

function recoveryKeyFor(uid) {
  const secret =
    process.env.VAULT_RECOVERY_SECRET || "lifewalletpuelo-vault-recovery-v1";
  return crypto.createHash("sha256").update(`${secret}:${uid}`).digest();
}

function wrapDek(dekBuf, uid) {
  const key = recoveryKeyFor(uid);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(dekBuf), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([Buffer.from([1]), iv, tag, enc]).toString("base64");
}

function unwrapDek(packedB64, uid) {
  const raw = Buffer.from(packedB64, "base64");
  if (raw.length < 1 + 12 + 16 || raw[0] !== 1) {
    throw new Error("Formato recovery inválido");
  }
  const iv = raw.subarray(1, 13);
  const tag = raw.subarray(13, 29);
  const enc = raw.subarray(29);
  const key = recoveryKeyFor(uid);
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]);
}

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
}

exports.registerVaultRecovery = onCall(
  { cors: true, memory: "256MiB", timeoutSeconds: 30 },
  async (request) => {
    const uid = requireAuthUid(request);
    const dekBase64 = request.data && request.data.dekBase64;
    if (!dekBase64 || typeof dekBase64 !== "string") {
      throw new HttpsError("invalid-argument", "dekBase64 requerido");
    }
    let dekBuf;
    try {
      dekBuf = Buffer.from(dekBase64, "base64");
    } catch (e) {
      throw new HttpsError("invalid-argument", "dekBase64 inválido");
    }
    if (dekBuf.length < 16 || dekBuf.length > 64) {
      throw new HttpsError("invalid-argument", "DEK de tamaño inválido");
    }
    const wrapped = wrapDek(dekBuf, uid);
    await db.collection("usuarios").doc(uid).collection("vault").doc("meta").set(
      {
        dek_wrapped_recovery: wrapped,
        recovery_v: 1,
        recoveryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { ok: true };
  }
);

exports.recoverVaultDek = onCall(
  { cors: true, memory: "256MiB", timeoutSeconds: 30 },
  async (request) => {
    const uid = requireAuthUid(request);
    const snap = await db.collection("usuarios").doc(uid).collection("vault").doc("meta").get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "No hay bóveda");
    }
    const wrapped = snap.get("dek_wrapped_recovery");
    if (!wrapped || typeof wrapped !== "string") {
      throw new HttpsError(
        "failed-precondition",
        "Esta bóveda no tiene recuperación. Podés empezar de cero."
      );
    }
    try {
      const dekBuf = unwrapDek(wrapped, uid);
      return { dekBase64: dekBuf.toString("base64") };
    } catch (e) {
      console.error("unwrap recovery", e);
      throw new HttpsError("internal", "No se pudo recuperar la clave");
    }
  }
);

const RECIBO_CONCEPTOS = new Set(["sena", "anticipo", "saldo", "pago_total", "otro"]);

function reciboHmacSecret() {
  return (
    process.env.RECIBO_HMAC_SECRET ||
    process.env.VAULT_RECOVERY_SECRET ||
    "lifewalletpuelo-recibo-hmac-v1"
  );
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
  return crypto.createHmac("sha256", reciboHmacSecret()).update(canonicalReciboPayload(payloadObj)).digest("hex");
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
  { cors: true, memory: "256MiB", timeoutSeconds: 30 },
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
  { cors: true, memory: "256MiB", timeoutSeconds: 30 },
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

exports.enviarMensajeTexto = require("./mensajes_texto").enviarMensajeTexto;

const calificacionAviso = require("./calificacion_aviso");
exports.avisarCalificacionPrestador = calificacionAviso.avisarCalificacionPrestador;
exports.responderCalificacion = calificacionAviso.responderCalificacion;

const { runFiadosVtoBatch } = require("./fiados_vto");

exports.fiadosVtoDaily = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const result = await runFiadosVtoBatch({ force: false });
    console.log("fiadosVtoDaily", result);
    return result;
  }
);

exports.fiadosVtoEvening = onSchedule(
  {
    schedule: "0 18 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const result = await runFiadosVtoBatch({ force: false });
    console.log("fiadosVtoEvening", result);
    return result;
  }
);

exports.fiadosVtoHttp = onRequest(
  {
    invoker: "public",
    secrets: ["BATCH_SECRET"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (req, res) => {
    applyCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST" && req.method !== "GET") {
      res.status(405).send("Method not allowed");
      return;
    }
    const secret = process.env.BATCH_SECRET || "";
    const provided =
      req.get("X-Batch-Secret") ||
      req.query.secret ||
      (req.body && req.body.secret) ||
      "";
    if (!secret) {
      res.status(503).json({ error: "batch_secret_not_configured" });
      return;
    }
    if (!timingSafeEqualString(provided, secret)) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }
    const force = req.query.force === "1" || (req.body && req.body.force === true);
    try {
      const result = await runFiadosVtoBatch({ force });
      res.status(200).json(result);
    } catch (e) {
      console.error("fiadosVtoHttp", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);

const authEmails = require("./auth_emails");
exports.sendAuthEmail = authEmails.sendAuthEmail;
