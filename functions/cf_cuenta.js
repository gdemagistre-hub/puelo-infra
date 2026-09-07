/**
 * Etapa 1 App Review — baja de cuenta in-app.
 *
 * solicitarEliminacionCuenta: anonymiza ya, borra Auth, encola purge 02:30.
 * purgeCuentasEliminadas: helper del batch diario (no es CF publicada).
 *
 * El mensaje al desarrollador vive en auth_emails.js (mismo SMTP que verify).
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const nodemailer = require("nodemailer");
const { admin, db, requireAuthUid } = require("./cf_shared");
const { PII_KEYS } = require("./pii");

const FROM_EMAIL = "no-reply@puelo.app";
const TO_DEV = "dev@puelo.app";
const PURGE_LIMIT = 8;
const SUBCOL_PAGE = 200;

const SUBCOLS_PURGE = [
  "privado",
  "movimientos",
  "fiados",
  "metas",
  "vencimientos",
];

const EXTRA_PUBLIC_DELETE = [
  "apellido",
  "nombre_completo",
  "display_name",
  "url_foto_perfil",
  "foto_url",
  "foto_perfil",
  "instagram",
  "usuario_instagram",
  "zonas_cobertura",
  "direccion_geo",
  "localidad",
  "partido",
  "provincia",
  "profesiones",
  "categorias_servicio",
  "oficio_libre",
  "capacitaciones",
  "list_oficios",
  "list_zona",
  "list_localidad",
  "list_partido",
  "list_provincia",
  "validaciones_inbox",
  "validaciones_recibidas",
];

function getTransport() {
  const pass = process.env.IONOS_SMTP_PASS || "";
  if (!pass) {
    const err = new Error("IONOS_SMTP_PASS not configured");
    err.code = "no_smtp_pass";
    throw err;
  }
  return nodemailer.createTransport({
    host: "smtp.ionos.com",
    port: 587,
    secure: false,
    requireTLS: true,
    connectionTimeout: 12000,
    greetingTimeout: 12000,
    socketTimeout: 15000,
    auth: { user: FROM_EMAIL, pass },
  });
}

function escapeHtml(s) {
  return String(s || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

async function sendDevMail({ subject, html }) {
  const transport = getTransport();
  const info = await transport.sendMail({
    from: `Puelo <${FROM_EMAIL}>`,
    to: TO_DEV,
    subject,
    html,
  });
  console.log("cf_cuenta mail", { subject, messageId: info.messageId });
  return info;
}

function parentAnonymizePatch(parent) {
  const del = admin.firestore.FieldValue.delete();
  const patch = {
    cuenta_eliminada: true,
    eliminada_at: admin.firestore.FieldValue.serverTimestamp(),
    purge_status: "pendiente",
    nombre: "Cuenta eliminada",
    es_trabajador: false,
    rol: "eliminado",
    camino_elegido: "eliminado",
    tiene_telefono: false,
    tiene_whatsapp: false,
    visible_buscador: false,
    list_promedio: 0,
    list_n_evaluaciones: 0,
    url_foto_perfil: del,
  };
  for (const k of PII_KEYS) {
    if (parent && parent[k] !== undefined) patch[k] = del;
  }
  for (const k of EXTRA_PUBLIC_DELETE) {
    if (k === "url_foto_perfil") continue;
    if (parent && parent[k] !== undefined) patch[k] = del;
  }
  return patch;
}

async function anonymizeUsuario(uid) {
  const ref = db.collection("usuarios").doc(uid);
  const snap = await ref.get();
  const parent = snap.exists ? snap.data() || {} : {};
  if (parent.cuenta_eliminada === true && parent.purge_status === "done") {
    return { already: true, parent };
  }
  await ref.set(parentAnonymizePatch(parent), { merge: true });
  try {
    await ref.collection("privado").doc("identidad").delete();
  } catch (e) {
    console.warn("cf_cuenta identidad delete", uid, e && e.message);
  }
  await db
    .collection("cuenta_eliminaciones")
    .doc(uid)
    .set(
      {
        uid,
        status: "pendiente",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        source: "solicitarEliminacionCuenta",
      },
      { merge: true }
    );
  return { already: false, parent };
}

async function deleteAuthUser(uid) {
  try {
    await admin.auth().deleteUser(uid);
    return { deleted: true };
  } catch (e) {
    if (e && e.code === "auth/user-not-found") {
      return { deleted: false, reason: "already_gone" };
    }
    console.error("cf_cuenta auth.deleteUser", uid, e);
    throw new HttpsError(
      "internal",
      "No se pudo cerrar el acceso de la cuenta. Probá de nuevo."
    );
  }
}

async function deleteStoragePrefix(uid) {
  const bucket = admin.storage().bucket();
  const prefix = `usuarios/${uid}/`;
  const [files] = await bucket.getFiles({ prefix, maxResults: 80 });
  let deleted = 0;
  for (const f of files) {
    try {
      await f.delete();
      deleted += 1;
    } catch (e) {
      console.warn("cf_cuenta storage", f.name, e && e.message);
    }
  }
  return { deleted, more: files.length >= 80 };
}

async function deleteSubcollection(uid, name) {
  const col = db.collection("usuarios").doc(uid).collection(name);
  const snap = await col.limit(SUBCOL_PAGE).get();
  if (snap.empty) return { deleted: 0, more: false };
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return { deleted: snap.size, more: snap.size >= SUBCOL_PAGE };
}

async function purgeOne(uid) {
  const storage = await deleteStoragePrefix(uid);
  const subs = {};
  let moreSubs = false;
  for (const name of SUBCOLS_PURGE) {
    const r = await deleteSubcollection(uid, name);
    subs[name] = r.deleted;
    if (r.more) moreSubs = true;
  }
  const done = !storage.more && !moreSubs;
  await db
    .collection("cuenta_eliminaciones")
    .doc(uid)
    .set(
      {
        status: done ? "done" : "pendiente",
        purged_at: admin.firestore.FieldValue.serverTimestamp(),
        storage_deleted: admin.firestore.FieldValue.increment(storage.deleted),
        last_subs: subs,
      },
      { merge: true }
    );
  await db
    .collection("usuarios")
    .doc(uid)
    .set(
      {
        purge_status: done ? "done" : "pendiente",
        purge_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  return { uid, done, storage, subs };
}

async function purgeCuentasEliminadas({ limit } = {}) {
  const cap = Math.min(Number(limit) || PURGE_LIMIT, 20);
  const snap = await db
    .collection("cuenta_eliminaciones")
    .where("status", "==", "pendiente")
    .limit(cap)
    .get();
  const out = [];
  for (const doc of snap.docs) {
    try {
      out.push(await purgeOne(doc.id));
    } catch (e) {
      console.error("purgeCuentasEliminadas", doc.id, e);
      out.push({ uid: doc.id, done: false, error: String(e.message || e) });
    }
  }
  return { ok: true, scanned: snap.size, results: out };
}

exports.purgeCuentasEliminadas = purgeCuentasEliminadas;

exports.solicitarEliminacionCuenta = onCall(
  {
    region: "us-east1",
    memory: "256MiB",
    timeoutSeconds: 60,
    secrets: ["IONOS_SMTP_PASS"],
  },
  async (request) => {
    const uid = requireAuthUid(request);
    if (request.auth && request.auth.token && request.auth.token.admin === true) {
      throw new HttpsError(
        "failed-precondition",
        "Las cuentas admin no se eliminan desde la app."
      );
    }
    const email = String(
      (request.auth && request.auth.token && request.auth.token.email) || ""
    ).slice(0, 120);
    await anonymizeUsuario(uid);
    const authOut = await deleteAuthUser(uid);
    try {
      await sendDevMail({
        subject: `[Puelo] Baja de cuenta ${uid.slice(0, 8)}`,
        html: `<!DOCTYPE html><html><body style="font-family:system-ui,sans-serif;color:#0f172a">
  <div style="max-width:560px;margin:24px auto">
    <h2 style="color:#734BE4">Pedido de eliminación</h2>
    <p>La cuenta ya no puede iniciar sesión. Purge de archivos en el batch 02:30 ART.</p>
    <p style="font-size:13px;color:#64748b">uid: ${escapeHtml(uid)}<br/>email Auth: ${escapeHtml(email || "(sin email)")}<br/>auth_deleted: ${authOut.deleted}</p>
  </div></body></html>`,
      });
    } catch (e) {
      console.warn("solicitarEliminacionCuenta mail", e && e.message);
    }
    return {
      ok: true,
      deleted: true,
      auth_deleted: !!authOut.deleted,
      purge: "24h",
    };
  }
);
