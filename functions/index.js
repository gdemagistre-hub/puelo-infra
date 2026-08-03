/**
 * Cloud Functions — Puelo scoring + validación de domicilio (admin bypass rules).
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
  region: "southamerica-east1",
  memory: "1GiB",
  timeoutSeconds: 540,
});

function cors(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

/** HTTP: POST/GET scoring batch */
exports.scoringBatchHttp = onRequest({ invoker: "public" }, async (req, res) => {
  cors(res);
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
    req.get("X-Batch-Secret") || req.query.secret || (req.body && req.body.secret) || "";
  if (secret && provided !== secret) {
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
});

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
 * Guarda respuesta de "Ayudar a validar" (admin SDK → ignora rules del cliente).
 * POST JSON: { targetUserId, targetNombre, conoce, domicilioSeleccionado,
 *   domicilioReal, esCorrecto, tiempoViviendo }
 * → { ok, token }
 */
exports.submitValidacionPendiente = onRequest(
  { invoker: "public", cors: true, memory: "256MiB", timeoutSeconds: 60 },
  async (req, res) => {
    cors(res);
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
      // Escribimos en ambas colecciones por compatibilidad de rules/código
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
 * Aplica la validación pendiente al perfil del target y al validador.
 * POST JSON: { token, validadorId }
 */
exports.aplicarValidacionPendiente = onRequest(
  { invoker: "public", cors: true, memory: "256MiB", timeoutSeconds: 60 },
  async (req, res) => {
    cors(res);
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
      const validadorId = String(b.validadorId || "").trim();
      if (!token || !validadorId) {
        res.status(400).json({ error: "token_and_validadorId_required" });
        return;
      }

      // Buscar pendiente en cualquiera de las 3 colecciones
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
        res.status(200).json({ ok: true, already: true, estado: pend.estado });
        return;
      }
      if (pend.tipo && !String(pend.tipo).includes("pendiente") && pend.tipo !== "validacion_pendiente" && pend.tipo !== "pendiente_domicilio") {
        // still allow if estado pendiente
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

      // Anti-granja (misma lógica simple que scoring_service)
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
      };

      const batch = db.batch();
      batch.update(pendRef, {
        tipo: "validacion_aplicada",
        validadorId,
        estado: "completado",
        procesado_en: admin.firestore.FieldValue.serverTimestamp(),
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
      });
    } catch (e) {
      console.error("aplicarValidacionPendiente", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);
