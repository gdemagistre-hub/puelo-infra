/**
 * R4: saca telefono/celular del doc público usuarios/{uid}.
 * Copia antes a privado/identidad. Solo claim admin.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { extractPii, telefonoDe } = require("./pii");

const db = admin.firestore();

function requireAdmin(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Solo admin");
  }
}

exports.sanitizarTelefonoPublico = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 120,
    region: "us-east1",
  },
  async (request) => {
    requireAdmin(request);
    const snap = await db.collection("usuarios").limit(200).get();
    let scanned = 0;
    let copied = 0;
    let stripped = 0;
    const batch = db.batch();
    for (const doc of snap.docs) {
      scanned += 1;
      const parent = doc.data() || {};
      const { pii, deletes } = extractPii(parent);
      const telKeys = ["telefono", "celular", "phone", "whatsapp", "telefono_whatsapp"];
      const hasTelField = telKeys.some((k) => parent[k] != null);
      if (!hasTelField) continue;
      const telPii = {};
      for (const k of telKeys) {
        if (parent[k] != null) telPii[k] = parent[k];
      }
      if (Object.keys(telPii).length) {
        batch.set(
          doc.ref.collection("privado").doc("identidad"),
          { ...telPii, updated_at: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true }
        );
        copied += 1;
      }
      const parentPatch = {};
      for (const k of telKeys) {
        if (parent[k] != null) {
          parentPatch[k] = admin.firestore.FieldValue.delete();
        }
      }
      const tel = telefonoDe({ ...parent, ...pii });
      if (tel) {
        parentPatch.tiene_telefono = true;
        if (parent.tiene_whatsapp !== false) {
          parentPatch.tiene_whatsapp = parent.tiene_whatsapp === true || true;
        }
      }
      if (Object.keys(parentPatch).length) {
        batch.set(doc.ref, parentPatch, { merge: true });
        stripped += 1;
      }
    }
    if (copied + stripped > 0) await batch.commit();
    return { ok: true, scanned, copied, stripped };
  }
);
