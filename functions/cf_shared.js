const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

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

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
}

function requireBatchSecret(req, res) {
  const secret = process.env.BATCH_SECRET || "";
  const provided = String(req.get("X-Batch-Secret") || "").trim();
  if (!secret) {
    res.status(503).json({ error: "batch_secret_not_configured" });
    return false;
  }
  if (!timingSafeEqualString(provided, secret)) {
    res.status(401).json({ error: "unauthorized" });
    return false;
  }
  return true;
}

module.exports = {
  admin,
  db,
  crypto,
  HttpsError,
  ALLOWED_ORIGINS,
  applyCors,
  timingSafeEqualString,
  verifyBearer,
  requireAuthUid,
  requireBatchSecret,
};
