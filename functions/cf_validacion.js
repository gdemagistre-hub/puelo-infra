/**
 * Validación vecinal — S1 + R3 (2026-09-02)
 * Calle real solo se usa en memoria para calcular esCorrecto.
 * Preview: opciones fijadas por par validador+target (no rotan).
 * Persistencia: validaciones / validaciones_pendientes (rules read,write false).
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

const PREVIEW_HITS_MAX = 12;

function stripCalleFields(data) {
  if (!data || typeof data !== "object") return data;
  const out = { ...data };
  delete out.domicilioReal;
  delete out.domicilioSeleccionado;
  return out;
}

function registroValidacionPublico(pend, validadorId, via) {
  return {
    conoce: !!(pend && pend.conoce),
    esCorrecto: !!(pend && pend.esCorrecto),
    tiempoViviendo: String((pend && pend.tiempoViviendo) || "").slice(0, 80),
    fecha: admin.firestore.FieldValue.serverTimestamp(),
    tipo: "identidad",
    via,
  };
}

function quizLockId(validadorId, targetUserId) {
  const a = String(validadorId || "").replace(/\//g, "_");
  const b = String(targetUserId || "").replace(/\//g, "_");
  return `quiz_${a}_${b}`.slice(0, 700);
}

async function opcionesFijasParaPar(validadorId, targetUserId, real) {
  const ref = db.collection("validaciones_pendientes").doc(
    quizLockId(validadorId, targetUserId)
  );
  const snap = await ref.get();
  const data = snap.exists ? snap.data() || {} : {};
  if (Array.isArray(data.opciones) && data.opciones.length >= 3) {
    const hits = Number(data.preview_hits || 0) || 0;
    if (hits >= PREVIEW_HITS_MAX) {
      const err = new Error("quiz_rate");
      err.code = "quiz_rate";
      throw err;
    }
    await ref.set(
      {
        preview_hits: hits + 1,
        last_preview_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return data.opciones.slice(0, 3).map((s) => String(s));
  }
  const opciones = opcionesQuiz(real);
  await ref.set(
    {
      tipo: "quiz_lock",
      targetUserId,
      validadorId,
      opciones,
      preview_hits: 1,
      creado_en: admin.firestore.FieldValue.serverTimestamp(),
      last_preview_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return opciones;
}

async function findPendienteValidacion(token) {
  const cols = ["validaciones", "validaciones_pendientes", "calificaciones"];
  for (const col of cols) {
    const ref = db.collection(col).doc(token);
    const snap = await ref.get();
    if (snap.exists) {
      return { ref, snap, col, data: snap.data() || {} };
    }
  }
  return null;
}

async function deleteCalificacionLeak(token) {
  try {
    await db.collection("calificaciones").doc(token).delete();
  } catch (_) {}
}

async function purgeValidacionPiiFromCalificaciones({ limit = 200 } = {}) {
  const tipos = ["validacion_pendiente", "validacion_aplicada"];
  let scanned = 0;
  let purged = 0;
  let batch = db.batch();
  let n = 0;
  for (const tipo of tipos) {
    const snap = await db
      .collection("calificaciones")
      .where("tipo", "==", tipo)
      .limit(limit)
      .get();
    for (const doc of snap.docs) {
      scanned += 1;
      const safe = stripCalleFields(doc.data() || {});
      batch.set(db.collection("validaciones").doc(doc.id), safe, { merge: true });
      batch.delete(doc.ref);
      n += 2;
      purged += 1;
      if (n >= 400) {
        await batch.commit();
        batch = db.batch();
        n = 0;
      }
    }
  }
  if (n > 0) await batch.commit();
  return { scanned, purged };
}

const httpOpts = {
  invoker: "public",
  cors: ALLOWED_ORIGINS,
  memory: "256MiB",
  timeoutSeconds: 60,
};

const previewValidacionPendiente = onRequest(httpOpts, async (req, res) => {
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
    const targetUserId = String(b.targetUserId || req.query.targetUserId || "").trim();
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
    let opciones;
    try {
      opciones = await opcionesFijasParaPar(validadorId, targetUserId, real);
    } catch (e) {
      if (e && e.code === "quiz_rate") {
        res.status(429).json({ error: "quiz_rate" });
        return;
      }
      throw e;
    }
    res.status(200).json({
      ok: true,
      nombre: nombreDe(loaded.merged),
      opciones,
    });
  } catch (e) {
    console.error("previewValidacionPendiente", e);
    res.status(500).json({ error: String(e.message || e) });
  }
});

const submitValidacionPendiente = onRequest(httpOpts, async (req, res) => {
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
    let validadorId = "";
    try {
      const decoded = await verifyBearer(req);
      if (decoded && decoded.uid) validadorId = decoded.uid;
    } catch (authErr) {
      console.warn("submitValidacion token invalid", authErr.message || authErr);
    }
    if (!validadorId) {
      res.status(401).json({ error: "unauthenticated" });
      return;
    }
    const b = req.body || {};
    const targetUserId = String(b.targetUserId || "").trim();
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
    const domicilioReal = domicilioRealDe(loaded.merged);
    if (!domicilioReal) {
      res.status(400).json({ error: "no_domicilio" });
      return;
    }
    const domicilioSeleccionado = String(b.domicilioSeleccionado || "").slice(0, 300);
    const esCorrecto = domicilioSeleccionado === domicilioReal;
    const token = String(b.token || "").trim() || db.collection("_").doc().id;
    const doc = {
      tipo: "validacion_pendiente",
      targetUserId,
      validadorId,
      targetNombre: nombreDe(loaded.merged).slice(0, 120),
      conoce: !!b.conoce,
      esCorrecto,
      tiempoViviendo: String(b.tiempoViviendo || "").slice(0, 80),
      estado: "pendiente",
      creado_en: admin.firestore.FieldValue.serverTimestamp(),
      fuente: "cloud_function",
      pii_v: 1,
    };
    const batch = db.batch();
    batch.set(db.collection("validaciones").doc(token), doc);
    batch.set(db.collection("validaciones_pendientes").doc(token), doc);
    await batch.commit();
    res.status(200).json({ ok: true, token });
  } catch (e) {
    console.error("submitValidacionPendiente", e);
    res.status(500).json({ error: String(e.message || e) });
  }
});

const aplicarValidacionPendiente = onRequest(httpOpts, async (req, res) => {
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
      res.status(401).json({ error: "unauthenticated" });
      return;
    }
    const found = await findPendienteValidacion(token);
    if (!found) {
      res.status(404).json({ error: "pendiente_not_found" });
      return;
    }
    const pendRef = found.ref;
    const pend = found.data;
    if (pend.estado !== "pendiente") {
      await deleteCalificacionLeak(token);
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

    const rejectPatch = {
      tipo: "validacion_aplicada",
      estado: "rechazado_limite",
      procesado_en: admin.firestore.FieldValue.serverTimestamp(),
      domicilioReal: admin.firestore.FieldValue.delete(),
      domicilioSeleccionado: admin.firestore.FieldValue.delete(),
    };

    if (recibidas === 0 && emitidas >= 1) {
      await pendRef.update({
        ...rejectPatch,
        motivo_rechazo:
          "Para validar a otra persona, primero alguien tiene que validarte a vos.",
      });
      await deleteCalificacionLeak(token);
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
        await pendRef.update({ ...rejectPatch, motivo_rechazo: reason });
        await deleteCalificacionLeak(token);
        res.status(403).json({ error: "limit", reason });
        return;
      }
    }

    const registro = registroValidacionPublico(pend, validadorId, via);
    const privateDoc = {
      ...stripCalleFields(pend),
      tipo: "validacion_aplicada",
      validadorId,
      estado: "completado",
      via,
      procesado_en: admin.firestore.FieldValue.serverTimestamp(),
      domicilioReal: admin.firestore.FieldValue.delete(),
      domicilioSeleccionado: admin.firestore.FieldValue.delete(),
    };
    const batch = db.batch();
    batch.set(db.collection("validaciones").doc(token), privateDoc, { merge: true });
    batch.set(db.collection("validaciones_pendientes").doc(token), privateDoc, { merge: true });
    batch.delete(db.collection("calificaciones").doc(token));
    batch.update(db.collection("usuarios").doc(targetUserId), {
      validaciones_recibidas: admin.firestore.FieldValue.arrayUnion(registro),
      n_validaciones_recibidas: admin.firestore.FieldValue.increment(1),
    });
    batch.update(db.collection("usuarios").doc(validadorId), {
      validaciones_emitidas_count: admin.firestore.FieldValue.increment(1),
      validaciones_emitidas: admin.firestore.FieldValue.arrayUnion([
        {
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
});

module.exports = {
  previewValidacionPendiente,
  submitValidacionPendiente,
  aplicarValidacionPendiente,
  purgeValidacionPiiFromCalificaciones,
};
