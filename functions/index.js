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

/** Constant-time compare for shared secrets (mitigates timing attacks). */
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
