/**
 * Cloud Functions — Puelo (lifewalletpuelo)
 * Core exports live in index_core.js; this file adds fiados VTO batch.
 */
const core = require("./index_core");
Object.assign(exports, core);

const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { runFiadosVtoBatch } = require("./fiados_vto");

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
    "Content-Type, Authorization, X-Batch-Secret, X-Dev-Login-Secret"
  );
}

/** 08:00 AR — recordatorio de cobros vencidos / de hoy */
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

/** 18:00 AR — segundo pase del día */
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

/** HTTP manual (mismo secreto BATCH_SECRET que scoring) */
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
    if (provided !== secret) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }
    const force =
      req.query.force === "1" || (req.body && req.body.force === true);
    try {
      const result = await runFiadosVtoBatch({ force });
      res.status(200).json(result);
    } catch (e) {
      console.error("fiadosVtoHttp", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);
