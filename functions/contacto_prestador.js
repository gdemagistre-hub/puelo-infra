const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { loadMerged, nombreDe, telefonoDe } = require("./pii");

function requireAuthUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión Google");
  }
  return request.auth.uid;
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
    const tel = telefonoDe(loaded.merged);
    if (!tel) {
      throw new HttpsError(
        "failed-precondition",
        "Este prestador no cargó teléfono."
      );
    }
    const db = admin.firestore();
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
