/**
 * Aviso al prestador cuando un cliente califica un trabajo.
 * - Crea/actualiza conversación + evento calificacion_recibida (append-only)
 * - Push FCM al prestador
 * - responderCalificacion: acepta/publica + actualiza promedio en usuarios/{prestador}
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
}

function conversacionIdFor(uidA, uidB) {
  const a = String(uidA);
  const b = String(uidB);
  return a < b ? `${a}__${b}` : `${b}__${a}`;
}

async function tokensForUid(uid) {
  const snap = await db.collection("usuarios").doc(uid).get();
  if (!snap.exists) return [];
  const d = snap.data() || {};
  const out = new Set();
  if (typeof d.fcm_token === "string" && d.fcm_token.length > 20) {
    out.add(d.fcm_token);
  }
  const arr = d.fcm_tokens;
  if (Array.isArray(arr)) {
    for (const t of arr) {
      if (typeof t === "string" && t.length > 20) out.add(t);
    }
  }
  return [...out];
}

async function sendCalificacionPush(prestadorUid, payload) {
  const tokens = await tokensForUid(prestadorUid);
  if (!tokens.length) {
    return { success: 0, failure: 0, noToken: true };
  }
  try {
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        type: "calificacion_pendiente",
        open: "mensajes",
        conversacion_id: String(payload.conversacionId || ""),
        calificacion_id: String(payload.calificacionId || ""),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      webpush: {
        fcmOptions: {
          link: "https://lifewalletpuelo.web.app/",
        },
        notification: {
          title: payload.title,
          body: payload.body,
          icon: "/icons/Icon-192.png",
        },
      },
    });
    return {
      success: res.successCount,
      failure: res.failureCount,
      noToken: false,
    };
  } catch (e) {
    console.warn("sendCalificacionPush", e.message || e);
    return { success: 0, failure: 1, noToken: false, error: String(e.message || e) };
  }
}

function estrellasLabel(n) {
  const v = Number(n) || 0;
  if (v <= 0) return "una evaluación";
  if (v === 1) return "1 estrella";
  return `${v} estrellas`;
}

/**
 * Recalcula promedio y cantidad de evaluaciones publicadas del prestador
 * y escribe campos denormalizados que lee Home / tarjeta / buscador.
 */
async function refreshPromedioPrestador(prestadorUid) {
  if (!prestadorUid) return { n: 0, promedio: 0 };

  const snap = await db
    .collection("calificaciones")
    .where("prestador_id", "==", prestadorUid)
    .limit(200)
    .get();

  let sum = 0;
  let n = 0;
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const estado = String(d.estado || "").toLowerCase();
    const publicada =
      estado === "publicada" ||
      d.aceptado_por_prestador === true ||
      d.publica_por_timeout === true;
    if (!publicada) continue;
    const stars = Number(d.estrellas ?? d.rating) || 0;
    if (stars < 1 || stars > 5) continue;
    sum += stars;
    n += 1;
  }

  // Fallback: algunos docs usan trabajador_id en vez de prestador_id
  if (n === 0) {
    const snap2 = await db
      .collection("calificaciones")
      .where("trabajador_id", "==", prestadorUid)
      .limit(200)
      .get();
    for (const doc of snap2.docs) {
      const d = doc.data() || {};
      const estado = String(d.estado || "").toLowerCase();
      const publicada =
        estado === "publicada" ||
        d.aceptado_por_prestador === true ||
        d.publica_por_timeout === true;
      if (!publicada) continue;
      const stars = Number(d.estrellas ?? d.rating) || 0;
      if (stars < 1 || stars > 5) continue;
      sum += stars;
      n += 1;
    }
  }

  const promedio = n > 0 ? Math.round((sum / n) * 10) / 10 : 0;

  await db
    .collection("usuarios")
    .doc(prestadorUid)
    .set(
      {
        list_promedio: n > 0 ? promedio : null,
        list_n_evaluaciones: n,
        list_n_eval: n,
        promedioEstrellas: n > 0 ? promedio : 0,
        nEvaluaciones: n,
        cantidad_evaluaciones: n,
        cantidadEvaluadores: n,
        list_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return { n, promedio };
}

exports.avisarCalificacionPrestador = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 30,
    region: "us-east1",
  },
  async (request) => {
    const actorUid = requireAuthUid(request);
    const d = request.data || {};
    const calificacionId = String(d.calificacion_id || "").trim();
    const prestadorUid = String(d.prestador_uid || "").trim();
    const trabajoId = String(d.trabajo_id || "").trim();
    const estrellas = Math.min(5, Math.max(1, Number(d.estrellas) || 0));
    const comentario = String(d.comentario || "").trim().slice(0, 200);

    if (!calificacionId || !prestadorUid) {
      throw new HttpsError("invalid-argument", "calificacion_id y prestador_uid requeridos");
    }
    if (prestadorUid === actorUid) {
      throw new HttpsError("invalid-argument", "No podés calificarte a vos mismo");
    }
    if (estrellas < 1) {
      throw new HttpsError("invalid-argument", "estrellas inválidas");
    }

    const calRef = db.collection("calificaciones").doc(calificacionId);
    const calSnap = await calRef.get();
    if (!calSnap.exists) {
      throw new HttpsError("not-found", "Calificación no encontrada");
    }
    const cal = calSnap.data() || {};
    const clienteId = String(cal.cliente_id || "").trim();
    if (clienteId && clienteId !== actorUid) {
      throw new HttpsError("permission-denied", "No sos el autor de esta calificación");
    }
    const prestadorDoc =
      String(cal.prestador_id || cal.trabajador_id || "").trim() || prestadorUid;
    if (prestadorDoc !== prestadorUid) {
      throw new HttpsError("failed-precondition", "prestador no coincide");
    }

    const convId = conversacionIdFor(actorUid, prestadorUid);
    const convRef = db.collection("conversaciones").doc(convId);
    const convSnap = await convRef.get();

    if (convSnap.exists) {
      const existingPend = convSnap.get("pending_calificacion_id");
      if (existingPend === calificacionId) {
        const push = await sendCalificacionPush(prestadorUid, {
          title: "Evaluación pendiente",
          body: `Te calificaron con ${estrellasLabel(estrellas)}. Revisá en Mensajes.`,
          conversacionId: convId,
          calificacionId,
        });
        return {
          ok: true,
          already: true,
          conversacion_id: convId,
          push,
        };
      }
    }

    const createdAtIso = new Date().toISOString();
    const eventRef = convRef.collection("eventos").doc();
    const eventId = eventRef.id;

    const summary = `Evaluación · ${estrellasLabel(estrellas)} · Pendiente`;
    const participantes = [actorUid, prestadorUid].sort();

    const eventDoc = {
      tipo: "calificacion_recibida",
      actor_uid: actorUid,
      contraparte_uid: prestadorUid,
      calificacion_id: calificacionId,
      trabajo_id: trabajoId || String(cal.trabajo_id || ""),
      estrellas,
      comentario,
      estado: "pendiente",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at_iso: createdAtIso,
    };

    const batch = db.batch();
    if (!convSnap.exists) {
      batch.set(convRef, {
        participantes,
        cliente_uid: actorUid,
        prestador_uid: prestadorUid,
        origen: "calificacion",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        last_summary: summary,
        last_event_at: admin.firestore.FieldValue.serverTimestamp(),
        pending_calificacion_event_id: eventId,
        pending_calificacion_id: calificacionId,
        pending_calificacion_actor_uid: actorUid,
      });
    } else {
      batch.update(convRef, {
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        last_summary: summary,
        last_event_at: admin.firestore.FieldValue.serverTimestamp(),
        pending_calificacion_event_id: eventId,
        pending_calificacion_id: calificacionId,
        pending_calificacion_actor_uid: actorUid,
      });
    }
    batch.set(eventRef, eventDoc);

    batch.set(
      calRef,
      {
        conversacion_id: convId,
        calificacion_event_id: eventId,
        aviso_enviado_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await batch.commit();

    const push = await sendCalificacionPush(prestadorUid, {
      title: "Nueva evaluación de un cliente",
      body: `Te calificaron con ${estrellasLabel(estrellas)}. Abrí Mensajes para aceptar o responder.`,
      conversacionId: convId,
      calificacionId,
    });

    return {
      ok: true,
      conversacion_id: convId,
      event_id: eventId,
      push,
    };
  }
);

exports.responderCalificacion = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 45,
    region: "us-east1",
  },
  async (request) => {
    const actorUid = requireAuthUid(request);
    const d = request.data || {};
    const convId = String(d.conversacion_id || "").trim();
    const eventId = String(d.calificacion_event_id || "").trim();
    const decision = String(d.decision || "aceptado").trim().toLowerCase();
    const respuestaTexto = String(d.respuesta_texto || "").trim().slice(0, 200);

    if (!convId || !eventId) {
      throw new HttpsError("invalid-argument", "ids requeridos");
    }
    if (decision !== "aceptado" && decision !== "respondido") {
      throw new HttpsError("invalid-argument", "decision inválida");
    }

    const convRef = db.collection("conversaciones").doc(convId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
      throw new HttpsError("not-found", "Conversación no encontrada");
    }
    const conv = convSnap.data() || {};
    const partes = conv.participantes || [];
    if (!partes.includes(actorUid)) {
      throw new HttpsError("permission-denied", "No sos parte de este hilo");
    }

    const eventRef = convRef.collection("eventos").doc(eventId);
    const eventSnap = await eventRef.get();
    if (!eventSnap.exists) {
      throw new HttpsError("not-found", "Evento no encontrado");
    }
    const event = eventSnap.data() || {};
    if (event.tipo !== "calificacion_recibida") {
      throw new HttpsError("failed-precondition", "No es una calificación");
    }
    if (event.actor_uid === actorUid) {
      throw new HttpsError(
        "failed-precondition",
        "No podés responder tu propia calificación"
      );
    }
    if (event.contraparte_uid && event.contraparte_uid !== actorUid) {
      throw new HttpsError("permission-denied", "Esta evaluación no es para vos");
    }
    if (conv.pending_calificacion_event_id !== eventId) {
      throw new HttpsError(
        "failed-precondition",
        "Esta evaluación ya no está pendiente"
      );
    }

    const calificacionId = String(
      event.calificacion_id || conv.pending_calificacion_id || ""
    ).trim();
    if (!calificacionId) {
      throw new HttpsError("failed-precondition", "calificacion_id faltante");
    }

    const createdAtIso = new Date().toISOString();
    const respRef = convRef.collection("eventos").doc();
    const tieneRespuesta = respuestaTexto.length > 0 || decision === "respondido";

    const respDoc = {
      tipo: tieneRespuesta ? "calificacion_respondida" : "calificacion_aceptada",
      actor_uid: actorUid,
      calificacion_event_id: eventId,
      calificacion_id: calificacionId,
      decision: tieneRespuesta ? "respondido" : "aceptado",
      respuesta_texto: respuestaTexto,
      estrellas: event.estrellas || 0,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at_iso: createdAtIso,
    };

    const estrellas = Number(event.estrellas) || 0;
    const label = tieneRespuesta
      ? `Evaluación · ${estrellasLabel(estrellas)} · Respondida`
      : `Evaluación · ${estrellasLabel(estrellas)} · Aceptada`;

    const calUpdate = {
      estado: "publicada",
      aceptado_por_prestador: true,
      tiene_respuesta_prestador: tieneRespuesta,
      par_completo: true,
      respuesta_prestador: respuestaTexto,
      publicada_en: admin.firestore.FieldValue.serverTimestamp(),
      publica_por_timeout: false,
      respondido_por_uid: actorUid,
      respondido_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = db.batch();
    batch.set(respRef, respDoc);
    batch.update(eventRef, {
      estado: tieneRespuesta ? "respondida" : "aceptada",
      respondido_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(convRef, {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      last_summary: label,
      last_event_at: admin.firestore.FieldValue.serverTimestamp(),
      pending_calificacion_event_id: admin.firestore.FieldValue.delete(),
      pending_calificacion_id: admin.firestore.FieldValue.delete(),
      pending_calificacion_actor_uid: admin.firestore.FieldValue.delete(),
      last_calificacion_decision: respDoc.decision,
      last_calificacion_event_id: eventId,
      last_calificacion_respuesta_id: respRef.id,
    });
    batch.set(db.collection("calificaciones").doc(calificacionId), calUpdate, {
      merge: true,
    });

    const trabajoId = String(event.trabajo_id || "").trim();
    if (trabajoId) {
      batch.set(
        db.collection("trabajos").doc(trabajoId),
        {
          calificacion_estado: "publicada",
          aceptado_por_prestador: true,
        },
        { merge: true }
      );
    }

    await batch.commit();

    // Impacto inmediato en perfil (Home / tarjeta / buscador)
    let stats = { n: 0, promedio: 0 };
    try {
      stats = await refreshPromedioPrestador(actorUid);
    } catch (e) {
      console.warn("refreshPromedioPrestador", e.message || e);
    }

    return {
      ok: true,
      conversacion_id: convId,
      calificacion_id: calificacionId,
      calificacion_event_id: eventId,
      respuesta_event_id: respRef.id,
      decision: respDoc.decision,
      publicada: true,
      promedio: stats.promedio,
      n_evaluaciones: stats.n,
    };
  }
);
