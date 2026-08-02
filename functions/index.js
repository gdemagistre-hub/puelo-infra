/**
 * Puelo scoring batch — Cloud Functions entrypoints.
 *
 * Lógica de scorecard alineada a docs/scoring_model_v1.md y
 * lib/scoring_service.dart (modelVersion v1.0).
 *
 * Deploy:
 *   firebase deploy --only functions
 *
 * Scheduler (recomendado 05:30 UTC ≈ 02:30 ART):
 *   gcloud scheduler jobs create http puelo-scoring-daily \
 *     --schedule="30 5 * * *" --time-zone="America/Argentina/Buenos_Aires" \
 *     --uri="https://<REGION>-<PROJECT>.cloudfunctions.net/scoringBatchHttp" \
 *     --http-method=POST \
 *     --headers="X-Batch-Secret=${BATCH_SECRET}"
 *
 * O usar functions.pubsub.schedule (abajo) si el proyecto tiene billing.
 */
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

setGlobalOptions({ region: "southamerica-east1", memory: "1GiB", timeoutSeconds: 540 });

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const MODEL_VERSION = "v1.0";
const TECHO_IDENTIDAD = 50;
const TECHO_SERVICIO = 40;
const TECHO_CLIENTE = 30;
const LOCK_TTL_MS = 15 * 60 * 1000;
const VENTANA_MS = 7 * 24 * 60 * 60 * 1000;

const ESTADOS_PENDIENTES = new Set([
  "pendiente_respuesta_prestador",
  "borrador_par",
  "borrador_cliente",
  "pendiente",
]);
const ESTADOS_PUBLICADOS = new Set(["publicada", "publicado", "published"]);

function noVacio(v) {
  return v != null && String(v).trim().length > 0;
}

function normalizar(raw, techo) {
  if (techo <= 0) return 0;
  return Math.min(100, Math.max(0, Math.round((100 * raw) / techo)));
}

function nivelFromScore(score) {
  if (score >= 75) return "muy_alto";
  if (score >= 50) return "alto";
  if (score >= 25) return "medio";
  return "bajo";
}

function fechaAlta(data) {
  const raw = data.creado_en || data.created_at || data.fecha_alta;
  if (!raw) return null;
  if (raw.toDate) return raw.toDate();
  if (typeof raw === "string") return new Date(raw);
  return null;
}

function calcularScoreIdentidad(data, fotosPortfolio = 0) {
  const detalle = {};
  const add = (k, tiene, peso = 1) => {
    detalle[k] = tiene ? peso : 0;
  };
  const docValidado = data.doc_validado === true;
  const pesoAncla = docValidado ? 2 : 1;
  const auth = String(data.auth_provider || "").toLowerCase();
  add("auth_google", auth === "google", 3);
  add("auth_facebook", auth === "facebook", 2);
  add("auth_apple", auth === "apple", 3);
  if (!auth || !["google", "facebook", "apple"].includes(auth)) {
    add("auth_app", true, 1);
  }
  add("email", noVacio(data.email), 2);
  add("telefono", noVacio(data.telefono), 1);
  add("telefono_verificado", data.telefono_verificado === true, 4);
  add("email_verificado", data.email_verificado === true, 2);
  add("nombre", noVacio(data.nombre), pesoAncla);
  add("apellido", noVacio(data.apellido), pesoAncla);
  add("tipo_doc", noVacio(data.tipo_doc || data.tipo_documento), pesoAncla);
  add(
    "pais_doc",
    noVacio(data.pais_doc || data.pais_emision || data.documento_pais),
    pesoAncla
  );
  add(
    "doc_numero",
    noVacio(data.doc_numero || data.numero_documento || data.documento),
    pesoAncla
  );
  add("fecha_nacimiento", data.fecha_nacimiento != null, pesoAncla);
  add("genero_documento", noVacio(data.genero_documento || data.sexo_documento), 1);
  add("foto_documento", noVacio(data.url_foto_documento), 3);
  add("doc_ocr_validado", docValidado, 8);
  add("foto_perfil", noVacio(data.url_foto_perfil), 3);
  add("instagram", noVacio(data.instagram || data.usuario_instagram), 1);
  add("calle", noVacio(data.calle), 1);
  add("numero", noVacio(data.numero), 1);
  const geo = data.direccion_geo || {};
  add("provincia_dom", noVacio(geo.provincia_id || geo.provincia_nombre), 1);
  add("partido_dom", noVacio(geo.partido_id || geo.partido_nombre), 1);
  add("localidad_dom", noVacio(geo.localidad_id || geo.localidad_nombre), 2);
  add("cp", noVacio(data.cp || data.codigo_postal), 1);
  const esTrabajador = data.es_trabajador === true || data.rol === "trabajador";
  if (esTrabajador) {
    add("nombre_comercial", noVacio(data.nombre_comercial), 1);
    const profesiones = data.profesiones || [];
    add("oficios", profesiones.length > 0, 2);
    const zonas = data.zonas_cobertura || {};
    const locs = zonas.localidades || [];
    add("zona_cobertura", locs.length > 0, 2);
    detalle.fotos_trabajos_propias = Math.min(5, fotosPortfolio || 0);
  }
  const raw = Object.values(detalle).reduce((a, b) => a + b, 0);
  return { raw, score: normalizar(raw, TECHO_IDENTIDAD), detalle };
}

function multiplicadorEvaluador({
  evaluadorId,
  scoreIdentidadReceptor,
  scoreIdentidadEvaluadores,
  evaluadorTieneHistorial,
  evaluadorEsNuevo,
  soloIdentidad,
}) {
  if (!evaluadorId) return 0.25;
  if (soloIdentidad && !evaluadorTieneHistorial[evaluadorId]) return 0.15;
  if (evaluadorEsNuevo[evaluadorId]) return 0.25;
  const idEval = scoreIdentidadEvaluadores[evaluadorId] || 0;
  if (idEval <= scoreIdentidadReceptor) return 0.5;
  if (evaluadorTieneHistorial[evaluadorId]) return 1.0;
  return 0.7;
}

function calcularScoreServicio({
  eventos,
  scoreIdentidadEvaluadores,
  evaluadorTieneHistorial,
  evaluadorEsNuevo,
  scoreIdentidadReceptor,
}) {
  let rawDouble = 0;
  let nEval = 0;
  let nConFoto = 0;
  let nConComentario = 0;
  let sumaRating = 0;
  let nRating = 0;
  for (const e of eventos) {
    const tipo = String(e.tipo || e.tipo_validacion || "trabajo").toLowerCase();
    const conFoto =
      e.con_foto === true ||
      e.tiene_foto === true ||
      noVacio(e.url_foto) ||
      (Array.isArray(e.fotos) && e.fotos.length > 0);
    const conComentario = noVacio(e.comentario || e.texto || e.review);
    const evalId = String(e.evaluador_id || e.validador_id || e.usuario_id || "");
    let base;
    if (tipo.includes("identidad") || tipo === "quien_es" || tipo === "persona") {
      base = 3;
    } else if (conFoto && conComentario) base = 4;
    else if (conFoto) base = 3;
    else base = 2;
    if (e.foto_validada_por_cliente === true) base += 1;
    const mult = multiplicadorEvaluador({
      evaluadorId: evalId,
      scoreIdentidadReceptor,
      scoreIdentidadEvaluadores,
      evaluadorTieneHistorial,
      evaluadorEsNuevo,
      soloIdentidad: tipo.includes("identidad") || tipo === "quien_es",
    });
    const parBonus = e.par_completo === true ? 1.1 : 1.0;
    rawDouble += base * mult * parBonus;
    nEval++;
    if (conFoto) nConFoto++;
    if (conComentario) nConComentario++;
    const rating = e.rating ?? e.estrellas ?? e.puntaje;
    if (typeof rating === "number") {
      sumaRating += rating;
      nRating++;
    }
  }
  const raw = Math.round(rawDouble);
  return {
    raw,
    score: normalizar(raw, TECHO_SERVICIO),
    nEventos: nEval,
    nConFoto,
    nConComentario,
    ratingPromedio: nRating > 0 ? sumaRating / nRating : null,
  };
}

function calcularScoreCliente(args) {
  let rawDouble = 0;
  let n = 0;
  for (const e of args.eventos) {
    const evalId = String(e.evaluador_id || e.validador_id || e.usuario_id || "");
    const mult = multiplicadorEvaluador({
      evaluadorId: evalId,
      scoreIdentidadReceptor: args.scoreIdentidadReceptor,
      scoreIdentidadEvaluadores: args.scoreIdentidadEvaluadores,
      evaluadorTieneHistorial: args.evaluadorTieneHistorial,
      evaluadorEsNuevo: args.evaluadorEsNuevo,
      soloIdentidad: false,
    });
    const parBonus = e.par_completo === true ? 1.1 : 1.0;
    const aTiempo = e.respondio_en_plazo === true ? 0.5 : 0;
    rawDouble += 2 * mult * parBonus + aTiempo;
    n++;
  }
  let raw = Math.round(rawDouble);
  let score = normalizar(raw, TECHO_CLIENTE);
  if (args.scoreIdentidadReceptor < 25 && score > 60) score = 60;
  return { raw, score, nEventos: n };
}

function cumpleRegistrado(data) {
  const geo = data.direccion_geo || {};
  return (
    noVacio(data.nombre) &&
    noVacio(data.apellido) &&
    noVacio(data.telefono) &&
    noVacio(data.tipo_doc || data.tipo_documento) &&
    noVacio(data.pais_doc || data.pais_emision || data.documento_pais) &&
    noVacio(data.doc_numero || data.numero_documento || data.documento) &&
    noVacio(geo.provincia_id || geo.provincia_nombre) &&
    noVacio(geo.partido_id || geo.partido_nombre) &&
    noVacio(geo.localidad_id || geo.localidad_nombre)
  );
}

function calcularBadge(data, { fotosPortfolio, fotosClientes, validaciones6m, validadoresConCalif, nEvalTrabajo }) {
  const tieneFotos = fotosPortfolio + fotosClientes > 0;
  const tieneFotoPerfil = noVacio(data.url_foto_perfil);
  const docValidado = data.doc_validado === true;
  const registrado = cumpleRegistrado(data);
  const alta = fechaAlta(data);
  const esNuevo = alta && Date.now() - alta.getTime() < 30 * 86400000;
  if (
    registrado &&
    tieneFotos &&
    docValidado &&
    (validaciones6m >= 10 || nEvalTrabajo >= 10) &&
    validadoresConCalif >= 10
  ) {
    return "plata";
  }
  if (registrado && tieneFotos && docValidado) return "bronce_plus";
  if (registrado && (tieneFotos || (tieneFotoPerfil && nEvalTrabajo >= 1))) return "bronce";
  if (registrado) return "registrado";
  if (esNuevo) return "nuevo";
  return null;
}

function esPublicada(d) {
  const estado = String(d.estado || "").toLowerCase().trim();
  if (!estado) return true;
  if (ESTADOS_PUBLICADOS.has(estado)) return true;
  if (ESTADOS_PENDIENTES.has(estado)) return false;
  if (["anulada", "cancelada", "borrador"].includes(estado)) return false;
  return false;
}

function resolverUsuarioId(trabajo) {
  if (trabajo.usuario_id) return String(trabajo.usuario_id);
  const ref = trabajo.trabajadorRef;
  if (ref && ref.id) return ref.id;
  if (typeof ref === "string") return ref.includes("/") ? ref.split("/").pop() : ref;
  return null;
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

async function publicarVencidas() {
  let porTimeout = 0;
  let parCompleto = 0;
  const corte = new Date(Date.now() - VENTANA_MS);
  const snap = await db.collection("calificaciones").get();
  let batch = db.batch();
  let n = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    const estado = String(d.estado || "").toLowerCase();
    const ambos = d.par_completo === true || d.tiene_respuesta_prestador === true;
    const pendientePar =
      estado === "par_completo_pendiente_pub" ||
      (ambos && ESTADOS_PENDIENTES.has(estado));
    let fecha = null;
    const f = d.fecha || d.created_at || d.fecha_calificacion || d.creado_en;
    if (f && f.toDate) fecha = f.toDate();
    else if (typeof f === "string") fecha = new Date(f);

    if (pendientePar) {
      batch.set(
        doc.ref,
        {
          estado: "publicada",
          par_completo: true,
          publicada_en: admin.firestore.FieldValue.serverTimestamp(),
          publica_por_timeout: false,
        },
        { merge: true }
      );
      parCompleto++;
      n++;
    } else if (ESTADOS_PENDIENTES.has(estado) && fecha && fecha < corte) {
      batch.set(
        doc.ref,
        {
          estado: "publicada",
          publicada_en: admin.firestore.FieldValue.serverTimestamp(),
          publica_por_timeout: true,
          par_completo: false,
        },
        { merge: true }
      );
      porTimeout++;
      n++;
    }
    if (n >= 400) {
      await batch.commit();
      batch = db.batch();
      n = 0;
    }
  }
  if (n > 0) await batch.commit();
  return { porTimeout, parCompleto };
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
    return { status: "aborted_lock", runId, procesados: 0 };
  }

  await runRef.set({
    run_id: runId,
    started_at: admin.firestore.FieldValue.serverTimestamp(),
    trigger,
    model_version: MODEL_VERSION,
    status: "running",
  });

  let evalsPublicadasTimeout = 0;
  let evalsParCompleto = 0;
  try {
    const pub = await publicarVencidas();
    evalsPublicadasTimeout = pub.porTimeout;
    evalsParCompleto = pub.parCompleto;
  } catch (e) {
    errores.push(`F1: ${e.message || e}`);
  }

  const fotosPortfolio = {};
  const fotosClientes = {};
  try {
    const trabajos = await db.collection("trabajos").get();
    for (const t of trabajos.docs) {
      const d = t.data();
      const uid = resolverUsuarioId(d);
      if (!uid) continue;
      const imgs = d.imagenes || [];
      if (!imgs.length) continue;
      const esPortfolio =
        d.tipo === "portfolio" ||
        d.cuenta_como_experiencia === false ||
        d.cargadoPor === "Trabajador";
      if (esPortfolio) fotosPortfolio[uid] = (fotosPortfolio[uid] || 0) + imgs.length;
      else fotosClientes[uid] = (fotosClientes[uid] || 0) + imgs.length;
    }
  } catch (e) {
    errores.push(`F2_trabajos: ${e.message || e}`);
  }

  const califPorUsuario = {};
  const califComoCliente = {};
  try {
    const califs = await db.collection("calificaciones").get();
    for (const c of califs.docs) {
      const d = c.data();
      if (!esPublicada(d)) continue;
      const map = { ...d, _id: c.id };
      const prestadorId = String(
        d.prestador_id || d.trabajador_id || d.evaluado_id || d.usuario_evaluado || ""
      );
      const rolEval = String(d.rol_evaluado || d.tipo || "");
      if (prestadorId && !rolEval.toLowerCase().includes("cliente")) {
        (califPorUsuario[prestadorId] ||= []).push(map);
      }
      const clienteId = String(d.cliente_id || d.usuario_cliente || "");
      if (clienteId) (califComoCliente[clienteId] ||= []).push(map);
      else if (rolEval.toLowerCase().includes("cliente") && prestadorId) {
        (califComoCliente[prestadorId] ||= []).push(map);
      }
    }
  } catch (e) {
    errores.push(`F2_calif: ${e.message || e}`);
  }

  const usersSnap = await db.collection("usuarios").get();
  const scoreIdentidadCache = {};
  const esNuevoCache = {};
  const tieneHistorialCache = {};

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const id = calcularScoreIdentidad(data, fotosPortfolio[doc.id] || 0);
    scoreIdentidadCache[doc.id] = id.score;
    const alta = fechaAlta(data);
    esNuevoCache[doc.id] = !!(alta && Date.now() - alta.getTime() < 30 * 86400000);
    const nEval = Number(data.cantidadEvaluadores || 0);
    const nVal = Array.isArray(data.validaciones_recibidas)
      ? data.validaciones_recibidas.length
      : 0;
    tieneHistorialCache[doc.id] = nEval > 0 || nVal > 0;
  }

  let batch = db.batch();
  let enBatch = 0;
  let procesados = 0;
  let escritos = 0;

  for (const doc of usersSnap.docs) {
    try {
      const data = doc.data();
      const uid = doc.id;
      const fp = fotosPortfolio[uid] || 0;
      const fc = fotosClientes[uid] || 0;
      const identidad = calcularScoreIdentidad(data, fp);
      const eventosServicio = [...(califPorUsuario[uid] || [])];
      const vals = Array.isArray(data.validaciones_recibidas)
        ? data.validaciones_recibidas
        : [];
      for (const v of vals) {
        if (v && typeof v === "object") eventosServicio.push(v);
      }
      const servicio = calcularScoreServicio({
        eventos: eventosServicio,
        scoreIdentidadEvaluadores: scoreIdentidadCache,
        evaluadorTieneHistorial: tieneHistorialCache,
        evaluadorEsNuevo: esNuevoCache,
        scoreIdentidadReceptor: identidad.score,
      });
      const cliente = calcularScoreCliente({
        eventos: califComoCliente[uid] || [],
        scoreIdentidadEvaluadores: scoreIdentidadCache,
        evaluadorTieneHistorial: tieneHistorialCache,
        evaluadorEsNuevo: esNuevoCache,
        scoreIdentidadReceptor: identidad.score,
      });
      const esTrabajador = data.es_trabajador === true || data.rol === "trabajador";
      const creditoPreview = Math.round(
        0.35 * identidad.score + 0.25 * (esTrabajador ? servicio.score : cliente.score)
      );

      const corte = new Date(Date.now() - 183 * 86400000);
      const idsVal = new Set();
      for (const v of vals) {
        if (!v || typeof v !== "object") continue;
        let fecha = null;
        const f = v.fecha || v.created_at || v.fecha_validacion;
        if (f && f.toDate) fecha = f.toDate();
        else if (typeof f === "string") fecha = new Date(f);
        if (fecha && fecha < corte) continue;
        const vid = String(v.validador_id || v.usuario_id || v.uid || "");
        if (vid) idsVal.add(vid);
      }
      for (const e of eventosServicio) {
        let fecha = null;
        const f = e.fecha || e.created_at || e.fecha_calificacion;
        if (f && f.toDate) fecha = f.toDate();
        else if (typeof f === "string") fecha = new Date(f);
        if (fecha && fecha < corte) continue;
        const vid = String(e.evaluador_id || e.validador_id || e.usuario_id || "");
        if (vid) idsVal.add(vid);
      }
      let validadoresConCalif = 0;
      for (const vid of idsVal) {
        if (tieneHistorialCache[vid]) validadoresConCalif++;
      }

      const badge = calcularBadge(data, {
        fotosPortfolio: fp,
        fotosClientes: fc,
        validaciones6m: idsVal.size,
        validadoresConCalif,
        nEvalTrabajo: servicio.nEventos,
      });

      // score_credito compat: raw identidad + escalonado fotos clientes
      const detalleCred = { ...identidad.detalle };
      let ptsT = 0;
      if (fc >= 10) ptsT = 3;
      else if (fc >= 5) ptsT = 2;
      else if (fc >= 1) ptsT = 1;
      detalleCred.trabajos_clientes = ptsT;
      const scoreCredito = Object.values(detalleCred).reduce((a, b) => a + b, 0);

      const estrellas =
        servicio.nEventos > 0
          ? Math.min(5, Math.max(1, 1 + 4 * (servicio.score / 100)))
          : null;

      batch.set(
        doc.ref,
        {
          score_credito: scoreCredito,
          score_credito_detalle: detalleCred,
          badge_prestador: badge,
          score_actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
          badge_actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
          scoring_stale: false,
          scoring: {
            model_version: MODEL_VERSION,
            score_identidad: identidad.score,
            score_identidad_raw: identidad.raw,
            score_identidad_detalle: identidad.detalle,
            score_servicio: servicio.score,
            score_servicio_raw: servicio.raw,
            score_servicio_detalle: {
              n_eval: servicio.nEventos,
              n_con_foto: servicio.nConFoto,
              n_con_comentario: servicio.nConComentario,
            },
            score_cliente: cliente.score,
            score_cliente_raw: cliente.raw,
            score_cliente_detalle: { n_eval: cliente.nEventos },
            nivel_confianza: nivelFromScore(identidad.score),
            nivel_cliente: nivelFromScore(cliente.score),
            n_eval_trabajo: servicio.nEventos,
            n_eval_cliente: cliente.nEventos,
            rating_promedio: servicio.ratingPromedio ?? estrellas,
            score_credito_preview: creditoPreview,
            actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
            last_run_id: runId,
          },
          stats_scoring: {
            fotos_portfolio: fp,
            fotos_clientes: fc,
            validaciones_6m: idsVal.size,
            validadores_con_calificacion: validadoresConCalif,
            model_version: MODEL_VERSION,
          },
        },
        { merge: true }
      );
      enBatch++;
      escritos++;
      procesados++;
      if (enBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        enBatch = 0;
      }
    } catch (e) {
      errores.push(`F4_${doc.id}: ${e.message || e}`);
    }
  }
  if (enBatch > 0) await batch.commit();

  const duracionMs = Date.now() - started;
  const status = errores.length ? "ok_with_errors" : "ok";
  await jobRef.set(
    {
      ultima_corrida: admin.firestore.FieldValue.serverTimestamp(),
      usuarios_procesados: procesados,
      usuarios_actualizados: escritos,
      evals_publicadas_timeout: evalsPublicadasTimeout,
      evals_par_completo: evalsParCompleto,
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
        evals_publicadas_timeout: evalsPublicadasTimeout,
        evals_par_completo: evalsParCompleto,
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
    evalsPublicadasTimeout,
    evalsParCompleto,
    duracionMs,
    errores: errores.slice(0, 20),
  };
}

/** HTTP: POST con header X-Batch-Secret o query ?secret= */
exports.scoringBatchHttp = onRequest({ invoker: "public" }, async (req, res) => {
  if (req.method !== "POST" && req.method !== "GET") {
    res.status(405).send("Method not allowed");
    return;
  }
  const secret = process.env.BATCH_SECRET || "";
  const provided =
    req.get("X-Batch-Secret") || req.query.secret || req.body?.secret || "";
  if (secret && provided !== secret) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  const force = req.query.force === "1" || req.body?.force === true;
  const trigger = req.query.trigger || req.body?.trigger || "http";
  try {
    const result = await runScoringBatch({ trigger, force });
    res.status(200).json(result);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e.message || e) });
  }
});

/** Cron diario 02:30 America/Argentina/Buenos_Aires */
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
