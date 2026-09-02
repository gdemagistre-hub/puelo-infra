const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { loadMerged, nombreDe, telefonoDe } = require("./pii");

const CONTACTO_CUOTA_DIA = 40;

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
}

function esPrestadorDoc(data) {
  if (!data || typeof data !== "object") return false;
  if (data.es_trabajador === true) return true;
  const rol = String(data.rol || "").trim().toLowerCase();
  if (rol === "trabajador" || rol === "prestador") return true;
  const camino = String(data.camino_elegido || "").trim().toLowerCase();
  if (camino === "ofrezo" || camino === "ofrezco") return true;
  if (Array.isArray(data.profesiones) && data.profesiones.length > 0) return true;
  return false;
}

function ymdUtc(d) {
  return d.toISOString().slice(0, 10);
}

async function consumirCuotaContacto(db, actorUid, targetUid) {
  const ref = db
    .collection("usuarios")
    .doc(actorUid)
    .collection("privado")
    .doc("rate_contacto");
  const hoy = ymdUtc(new Date());
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() || {} : {};
    const dia = String(data.dia || "");
    const reset = dia !== hoy;
    const n = reset ? 0 : Number(data.n || 0) || 0;
    const destinos = reset || typeof data.destinos !== "object" || !data.destinos
      ? {}
      : { ...data.destinos };
    if (destinos[targetUid]) {
      return;
    }
    if (n >= CONTACTO_CUOTA_DIA) {
      throw new HttpsError(
        "resource-exhausted",
        "Llegaste al tope de contactos por hoy. Probá mañana."
      );
    }
    destinos[targetUid] = true;
    tx.set(
      ref,
      {
        dia: hoy,
        n: n + 1,
        destinos,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

exports.obtenerContactoPrestador = onCall(
  { cors: true, memory: "256MiB", timeoutSeconds: 30 },
  async (request) => {
    const actorUid = requireAuthUid(request);
    const d = request.data || {};
    const target = String(d.prestador_uid || "").trim();
    const tipo = String(d.tipo || "whatsapp").trim().toLowerCase();
    const origen = String(d.origen || "app").trim().slice(0, 40);
    if (!target || target === actorUid) {
      throw new HttpsError("invalid-argument", "prestador inválido");
    }
    if (tipo !== "whatsapp" && tipo !== "llamada") {
      throw new HttpsError("invalid-argument", "tipo inválido");
    }
    const loaded = await loadMerged(target);
    if (!loaded.merged) {
      throw new HttpsError("not-found", "Prestador no encontrado");
    }
    if (!esPrestadorDoc(loaded.parent || loaded.merged)) {
      throw new HttpsError(
        "permission-denied",
        "Solo se puede contactar a quien ofrece servicios."
      );
    }
    const tel = telefonoDe(loaded.merged);
    if (!tel) {
      throw new HttpsError(
        "failed-precondition",
        "Este prestador no cargó teléfono."
      );
    }
    const db = admin.firestore();
    await consumirCuotaContacto(db, actorUid, target);
    await db.collection("contactos").add({
      cliente_uid: actorUid,
      prestador_uid: target,
      tipo,
      origen,
      prestador_nombre: nombreDe(loaded.merged).slice(0, 120),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      via: "cf_obtenerContactoPrestador",
    });
    return {
      ok: true,
      telefono: tel,
      tiene_whatsapp: loaded.merged.tiene_whatsapp !== false,
    };
  }
);
