/**
 * Scoring batch core (Admin SDK).
 * Model v1.2-phase1.5-cf — batch diario sin depender de la app.
 */
const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const MODEL_VERSION = "v1.2-phase1-cf";
const LOCK_TTL_MS = 15 * 60 * 1000;

function noVacio(v) {
  return v != null && String(v).trim().length > 0;
}

async function adquirirLock(jobRef, runId, trigger, force) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(jobRef);
    const data = snap.data() || {};
    const lock = data.lock;
    if (!force && lock && lock.until) {
      const until = lock.until.toDate ? lock.until.toDate() : new Date(lock.until);
      if (until > new Date()) return false;
    }
    tx.set(
      jobRef,
      {
        lock: {
          holder: runId,
          trigger,
          acquired_at: admin.firestore.FieldValue.serverTimestamp(),
          until: admin.firestore.Timestamp.fromDate(new Date(Date.now() + LOCK_TTL_MS)),
        },
        status: "running",
      },
      { merge: true }
    );
    return true;
  });
}

function scoreIdentidadSimple(data) {
  let s = 0;
  const auth = String(data.auth_provider || "").toLowerCase();
  if (auth === "google") s += 15;
  if (noVacio(data.email)) s += 10;
  if (noVacio(data.telefono)) s += 8;
  if (data.doc_validado === true) s += 20;
  if (noVacio(data.url_foto_perfil)) s += 10;
  if (noVacio(data.nombre) && noVacio(data.apellido)) s += 10;
  const geo = data.direccion_geo || {};
  if (geo.localidad_id || geo.localidad_nombre) s += 10;
  if (Array.isArray(data.profesiones) && data.profesiones.length) s += 10;
  return Math.min(100, s);
}

function badgeSimple(data, scoreId) {
  const geo = data.direccion_geo || {};
  const base =
    noVacio(data.nombre) && noVacio(data.apellido) && noVacio(data.telefono);
  const reg =
    base &&
    noVacio(data.doc_numero || data.numero_documento) &&
    (geo.localidad_id || geo.localidad_nombre);
  if (base && data.doc_validado === true) return "bronce_plus";
  if (reg && scoreId >= 35) return "bronce";
  if (base) return "registrado";
  return "nuevo";
}

async function runScoringBatch({ trigger = "scheduler", force = false } = {}) {
  const started = Date.now();
  const runId = `${new Date(started).toISOString().replace(/[:.]/g, "-")}_${trigger}`;
  const errores = [];
  const jobRef = db.collection("stats").doc("scoring_job");
  const runRef = jobRef.collection("runs").doc(runId);

  const acquired = await adquirirLock(jobRef, runId, trigger, force);
  if (!acquired) {
    await runRef.set({
      run_id: runId,
      started_at: admin.firestore.FieldValue.serverTimestamp(),
      trigger,
      model_version: MODEL_VERSION,
      status: "aborted_lock",
      finished_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { status: "aborted_lock", runId, procesados: 0, actualizados: 0 };
  }

  await runRef.set({
    run_id: runId,
    started_at: admin.firestore.FieldValue.serverTimestamp(),
    trigger,
    model_version: MODEL_VERSION,
    status: "running",
  });

  let procesados = 0;
  let escritos = 0;
  try {
    const usersSnap = await db.collection("usuarios").get();
    let batch = db.batch();
    let n = 0;
    for (const doc of usersSnap.docs) {
      try {
        const data = doc.data();
        const scoreId = scoreIdentidadSimple(data);
        const badge = badgeSimple(data, scoreId);
        const features = {
          f_auth_google: String(data.auth_provider || "").toLowerCase() === "google" ? 1 : 0,
          f_email: data.email ? 1 : 0,
          f_telefono: data.telefono ? 1 : 0,
          f_doc_ocr: data.doc_validado === true ? 1 : 0,
          f_foto_perfil: data.url_foto_perfil ? 1 : 0,
          f_score_identidad: scoreId,
          y_badge: badge,
        };
        batch.set(
          doc.ref,
          {
            badge_prestador: badge,
            score_actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
            badge_actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
            scoring_stale: false,
            scoring: {
              model_version: MODEL_VERSION,
              score_identidad: scoreId,
              score_servicio: 0,
              score_cliente: 0,
              score_credito_preview: Math.round(0.35 * scoreId),
              actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
              last_run_id: runId,
            },
          },
          { merge: true }
        );
        batch.set(
          db.collection("scoring_features").doc(doc.id),
          {
            uid: doc.id,
            model_version: MODEL_VERSION,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
            last_run_id: runId,
            features,
            labels: { y_badge: badge, y_score_identidad: scoreId },
          },
          { merge: true }
        );
        n++;
        escritos++;
        procesados++;
        if (n >= 400) {
          await batch.commit();
          batch = db.batch();
          n = 0;
        }
      } catch (e) {
        errores.push(`F4_${doc.id}: ${e.message || e}`);
      }
    }
    if (n > 0) await batch.commit();
  } catch (e) {
    errores.push(`FATAL: ${e.message || e}`);
  }

  const duracionMs = Date.now() - started;
  const status = errores.length ? (procesados ? "ok_with_errors" : "error") : "ok";
  await jobRef.set(
    {
      ultima_corrida: admin.firestore.FieldValue.serverTimestamp(),
      usuarios_procesados: procesados,
      usuarios_actualizados: escritos,
      fuente: trigger,
      model_version: MODEL_VERSION,
      last_run_id: runId,
      status,
      duracion_ms: duracionMs,
      errores_count: errores.length,
      lock: admin.firestore.FieldValue.delete(),
    },
    { merge: true }
  );
  await runRef.set(
    {
      status,
      finished_at: admin.firestore.FieldValue.serverTimestamp(),
      duracion_ms: duracionMs,
      metrics: {
        usuarios_procesados: procesados,
        usuarios_actualizados: escritos,
        errores_count: errores.length,
      },
      errores: errores.slice(0, 50),
      model_version: MODEL_VERSION,
    },
    { merge: true }
  );

  return {
    status,
    runId,
    procesados,
    actualizados: escritos,
    duracionMs,
    errores: errores.slice(0, 20),
  };
}

const DEFAULT_OFICIOS = [
  "electricidad",
  "plomeria",
  "gasista",
  "carpinteria",
  "pintura",
  "albanileria",
  "jardineria",
  "limpieza",
];

const OFICIO_LABEL = {
  electricidad: "Electricista",
  plomeria: "Plomería",
  gasista: "Gasista",
  carpinteria: "Carpintería",
  pintura: "Pintura",
  albanileria: "Construcción",
  jardineria: "Jardinería",
  limpieza: "Limpieza",
};

function ymdArt(date) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Argentina/Buenos_Aires",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function startOfArtDay(ymd) {
  return new Date(`${ymd}T00:00:00-03:00`);
}

async function runTopServiciosAyer() {
  const today = ymdArt(new Date());
  const yesterday = ymdArt(new Date(Date.now() - 24 * 60 * 60 * 1000));
  const start = startOfArtDay(yesterday);
  const end = startOfArtDay(today);
  const counts = {};
  let scanned = 0;
  let last = null;
  while (true) {
    let q = db
      .collection("demanda_eventos")
      .where("created_at", ">=", start)
      .where("created_at", "<", end)
      .orderBy("created_at")
      .limit(500);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      scanned += 1;
      const id = String((doc.data() || {}).oficio_id || "")
        .trim()
        .toLowerCase();
      if (!id) continue;
      counts[id] = (counts[id] || 0) + 1;
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < 500) break;
  }

  const ranked = Object.keys(counts).sort((a, b) => counts[b] - counts[a]);
  const ids = [];
  for (const id of ranked) {
    if (!ids.includes(id)) ids.push(id);
    if (ids.length >= 8) break;
  }
  for (const id of DEFAULT_OFICIOS) {
    if (ids.length >= 8) break;
    if (!ids.includes(id)) ids.push(id);
  }

  const items = ids.slice(0, 8).map((id) => ({
    id,
    label: OFICIO_LABEL[id] || id.replace(/_/g, " "),
    n: counts[id] || 0,
  }));

  const payload = {
    fecha_fuente: yesterday,
    actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
    items,
    counts,
    eventos_ayer: scanned,
    fuente: scanned > 0 ? "demanda" : "fallback",
  };
  await db.collection("stats").doc("top_servicios").set(payload, { merge: true });
  return {
    status: "ok",
    fecha_fuente: yesterday,
    fuente: payload.fuente,
    eventos: scanned,
    items,
  };
}

module.exports = { runScoringBatch, runTopServiciosAyer, MODEL_VERSION };

