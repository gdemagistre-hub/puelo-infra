/**
 * Tarjeta digital compartible — token opaco 21 días.
 * El anónimo lee tarjetas_share/{token}, no usuarios/{uid}.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

const db = admin.firestore();
const TTL_MS = 21 * 24 * 3600 * 1000;
const HOST = "https://lifewalletpuelo.web.app";

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
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
    tiene_whatsapp: data.tiene_whatsapp === true,
    tiene_telefono: data.tiene_telefono === true,
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
    const userRef = db.collection("usuarios").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "No hay perfil");
    }
    const data = userSnap.data() || {};
    const snap = snapshotDe(uid, data);
    const now = Date.now();
    const expireAt = admin.firestore.Timestamp.fromMillis(now + TTL_MS);

    let token = String(data.tarjeta_share_token || "").trim();
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
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expire_at: expireAt,
    });
    await userRef.set({ tarjeta_share_token: token }, { merge: true });

    const url = `${HOST}/#/t/${token}`;
    return {
      ok: true,
      token,
      url,
      expires_at: new Date(now + TTL_MS).toISOString(),
      dias: 21,
    };
  }
);
