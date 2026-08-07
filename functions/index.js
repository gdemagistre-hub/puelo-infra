/**
 * Cloud Functions — Puelo scoring + validación de domicilio (admin bypass rules).
 * Sprint 0 (2026-08-06):
 * - BATCH_SECRET fail-closed (env / secret)
 * - aplicarValidacionPendiente con Auth Bearer preferente
 * - mintDevSession para "Modo prueba" con DEV_LOGIN_SECRET
 * - CORS acotado
 *
 * Config opcional (Firebase secrets o env):
 *   firebase functions:secrets:set BATCH_SECRET
 *   firebase functions:secrets:set DEV_LOGIN_SECRET
 *   firebase functions:config o params: ALLOW_DEV_VALIDACION=1|0
 */
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { runScoringBatch } = require("./scoringCore");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

setGlobalOptions({
  region: "us-east1",
  memory: "1GiB",
  timeoutSeconds: 540,
});

const ALLOWED_ORIGINS = [
  "https://lifewalletpuelo.web.app",
  "https://lifewalletpuelo.firebaseapp.com",
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
    "Content-Type, Authorization, X-Batch-Secret, X-Dev-Login-Secret"
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

/** HTTP: POST/GET scoring batch — secreto OBLIGATORIO */
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
    if (provided !== secret) {
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
    const result = await runScoringBatch({ trigger: "scheduler" });
    console.log("scoringBatchDaily", result);
    return result;
  }
);

/**
 * Menú "Modo prueba": custom token para el uid elegido.
 * Header X-Dev-Login-Secret == DEV_LOGIN_SECRET.
 */
exports.mintDevSession = onRequest(
  {
    invoker: "public",
    cors: ALLOWED_ORIGINS,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: ["DEV_LOGIN_SECRET"],
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
      const expected = process.env.DEV_LOGIN_SECRET || "";
      if (!expected) {
        res.status(503).json({ error: "dev_login_not_configured" });
        return;
      }
      const provided =
        req.get("X-Dev-Login-Secret") || (req.body && req.body.secret) || "";
      if (provided !== expected) {
        res.status(401).json({ error: "unauthorized" });
        return;
      }
      const uid = String((req.body && req.body.uid) || "").trim();
      if (!uid || uid.length > 128) {
        res.status(400).json({ error: "uid_required" });
        return;
      }
      const snap = await db.collection("usuarios").doc(uid).get();
      if (!snap.exists) {
        res.status(404).json({ error: "user_not_found" });
        return;
      }
      const token = await admin.auth().createCustomToken(uid, {
        dev_impersonation: true,
      });
      res.status(200).json({ ok: true, token, uid });
    } catch (e) {
      console.error("mintDevSession", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);

/**
 * Guarda respuesta de "Ayudar a validar" (admin SDK).
 * Público: el validador externo puede no tener sesión.
 */
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

/**
 * Aplica validación pendiente.
 * Preferente: Authorization Bearer → uid del token.
 * TEMP: ALLOW_DEV_VALIDACION=1 (default) acepta body.validadorId (dropdown local).
 */
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
