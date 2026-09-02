/**
 * Tarjeta digital compartible — token opaco 7 días.
 * Vitrina anónima: tarjetas_share/{token} (sin DNI/calle/teléfono).
 * El número se revela solo vía obtenerContactoPrestador con sesión.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { loadMerged, telefonoDe } = require("./pii");

const db = admin.firestore();
const TTL_DAYS = 7;
const TTL_MS = TTL_DAYS * 24 * 3600 * 1000;
const HOST = "https://lifewalletpuelo.web.app";

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
}

function requireAdmin(request) {
  const uid = requireAuthUid(request);
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Solo admin");
  }
  return uid;
}

function newToken() {
  return crypto.randomBytes(16).toString("hex");
}

function zonasNombres(data) {
  const out = [];
  const z = data.zonas_cobertura;
  if (z && Array.isArray(z.localidades)) {
    for (const e of z.localidades) {
      if (!e || typeof e !== "object") continue;
      const n = String(e.nombre || e.localidad_nombre || "").trim();
      if (n) out.push(n);
    }
  }
  const loc = String(data.localidad || data.localidad_nombre || "").trim();
  if (loc && !out.includes(loc)) out.push(loc);
  return out.slice(0, 8);
}

function snapshotDe(uid, data) {
  const profesiones = Array.isArray(data.profesiones)
    ? data.profesiones.map((p) => String(p).slice(0, 40)).slice(0, 8)
    : [];
  const nombres = zonasNombres(data);
  const scoring = data.scoring && typeof data.scoring === "object" ? data.scoring : {};
  const tel = telefonoDe(data).replace(/[^\d+]/g, "").slice(0, 20);
  const tieneTel = !!tel || data.tiene_telefono === true;
  const tieneWa = data.tiene_whatsapp === true || (tieneTel && data.tiene_whatsapp !== false);
  return {
    prestador_uid: uid,
    nombre: String(data.nombre || "").slice(0, 80),
    apellido: String(data.apellido || "").slice(0, 80),
    nombre_comercial: String(data.nombre_comercial || "").slice(0, 80),
    url_foto_perfil: String(data.url_foto_perfil || data.foto_perfil || "").slice(0, 500),
    profesiones,
    zonas_nombres: nombres,
    zonas_cobertura: {
      localidades: nombres.map((nombre) => ({ nombre })),
    },
    list_badge: String(data.list_badge || data.badge_prestador || "").slice(0, 32),
    list_score_identidad: Number(
      data.list_score_identidad ?? scoring.score_identidad ?? 0
    ) || 0,
    list_promedio: Number(data.list_promedio ?? data.promedioEstrellas ?? 0) || 0,
    list_n_evaluaciones:
      Number(data.list_n_evaluaciones ?? data.nEvaluaciones ?? 0) || 0,
    tiene_whatsapp: tieneWa,
    tiene_telefono: tieneTel,
  };
}

exports.crearTarjetaShare = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 30,
    region: "us-east1",
  },
  async (request) => {
    const uid = requireAuthUid(request);
    const rotar = !!(request.data && request.data.rotar);
    const loaded = await loadMerged(uid);
    if (!loaded.merged) {
      throw new HttpsError("not-found", "No hay perfil");
    }
    const data = loaded.merged;
    const snap = snapshotDe(uid, data);
    const now = Date.now();
    const expireAt = admin.firestore.Timestamp.fromMillis(now + TTL_MS);

    const parent = loaded.parent || {};
    let token = String(parent.tarjeta_share_token || "").trim();
    if (token && !rotar) {
      const existing = await db.collection("tarjetas_share").doc(token).get();
      const exp = existing.exists ? existing.get("expire_at") : null;
      const expMs = exp && exp.toMillis ? exp.toMillis() : 0;
      if (!existing.exists || expMs <= now) {
        token = "";
      }
    }

    if (rotar && token) {
      try {
        await db.collection("tarjetas_share").doc(token).delete();
      } catch (e) {
        console.warn("revoke old share", e.message || e);
      }
      token = "";
    }

    if (!token) token = newToken();

    await db.collection("tarjetas_share").doc(token).set({
      ...snap,
      telefono: admin.firestore.FieldValue.delete(),
      celular: admin.firestore.FieldValue.delete(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expire_at: expireAt,
    });
    await loaded.ref.set({ tarjeta_share_token: token }, { merge: true });

    const url = `${HOST}/#/t/${token}`;
    return {
      ok: true,
      token,
      url,
      expires_at: new Date(now + TTL_MS).toISOString(),
      dias: TTL_DAYS,
    };
  }
);

/** Admin: quita telefono/celular de snapshots vigentes. No enumera números. */
exports.sanitizarTarjetasShare = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
    region: "us-east1",
  },
  async (request) => {
    requireAdmin(request);
    const snap = await db.collection("tarjetas_share").limit(200).get();
    let stripped = 0;
    const batch = db.batch();
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      if (d.telefono == null && d.celular == null) continue;
      batch.update(doc.ref, {
        telefono: admin.firestore.FieldValue.delete(),
        celular: admin.firestore.FieldValue.delete(),
      });
      stripped += 1;
    }
    if (stripped > 0) await batch.commit();
    return { ok: true, scanned: snap.size, stripped };
  }
);
