/**
 * Validacion vecinal — Etapa S1.
 * PII de domicilio NO va a calificaciones (lectura publica).
 */
const { onRequest } = require("firebase-functions/v2/https");
const {
  admin,
  db,
  ALLOWED_ORIGINS,
  applyCors,
  verifyBearer,
} = require("./cf_shared");
const { loadMerged, domicilioRealDe, opcionesQuiz, nombreDe } = require("./pii");

exports.previewValidacionPendiente = onRequest(
  { invoker: "public", cors: ALLOWED_ORIGINS, memory: "256MiB", timeoutSeconds: 60 },
  async (req, res) => {
    applyCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST" && req.method !== "GET") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }
    try {
      let validadorId = "";
      try {
        const decoded = await verifyBearer(req);
        if (decoded && decoded.uid) validadorId = decoded.uid;
      } catch (authErr) {
        console.warn("previewValidacion token invalid", authErr.message || authErr);
      }
      if (!validadorId) {
        res.status(401).json({ error: "unauthenticated" });
        return;
      }
      const b = req.body || {};
      const targetUserId = String(
        b.targetUserId || req.query.targetUserId || ""
      ).trim();
      if (!targetUserId) {
        res.status(400).json({ error: "targetUserId_required" });
        return;
      }
      if (targetUserId === validadorId) {
        res.status(400).json({ error: "no_self_validate" });
        return;
      }
      const loaded = await loadMerged(targetUserId);
      if (!loaded.merged) {
        res.status(404).json({ error: "not_found" });
        return;
      }
      const real = domicilioRealDe(loaded.merged);
      if (!real) {
        res.status(400).json({ error: "no_domicilio" });
        return;
      }
      res.status(200).json({
        ok: true,
        nombre: nombreDe(loaded.merged),
        opciones: opcionesQuiz(real),
      });
    } catch (e) {
      console.error("previewValidacionPendiente", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);
