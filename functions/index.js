/**
 * Cloud Functions — Puelo (lifewalletpuelo)
 * Scoring, validación domicilio, vault recovery (Mis números), mensajes recibos.
 */
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const crypto = require("crypto");
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

// NOTE: full body restored from e8212ab + M5 export. If incomplete, checkout e8212ab.
exports.enviarMensajeTexto = require("./mensajes_texto").enviarMensajeTexto;
// ---------------------------------------------------------------------------
// Mensajes M5 — texto libre (append-only)
// ---------------------------------------------------------------------------
exports.enviarMensajeTexto = require("./mensajes_texto").enviarMensajeTexto;
