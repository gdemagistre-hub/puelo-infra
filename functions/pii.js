/**
 * PII fuera del documento público usuarios/{uid}.
 * Copia en usuarios/{uid}/privado/identidad y borra del padre.
 */
const admin = require("firebase-admin");

const PII_KEYS = [
  "doc_numero",
  "numero_documento",
  "documento",
  "documento_tipo",
  "documento_pais",
  "tipo_doc",
  "tipo_documento",
  "pais_doc",
  "pais_emision",
  "genero_documento",
  "sexo_documento",
  "fecha_nacimiento",
  "email",
  "url_foto_documento",
  "foto_documento",
  "dni_frente",
  "dni_dorso",
  "url_dni_frente",
  "url_dni_dorso",
  "foto_dni_frente",
  "foto_dni_dorso",
  "calle",
  "numero",
  "piso",
  "piso_depto",
  "depto",
  "cp",
  "codigo_postal",
  "cuit",
  "cuil",
  "doc_hash_datos",
];

const CALLES_SENUELO = [
  "San Martín",
  "Belgrano",
  "Rivadavia",
  "Sarmiento",
  "Mitre",
  "Alsina",
  "Moreno",
  "Independencia",
  "25 de Mayo",
  "9 de Julio",
  "Lavalle",
  "Italia",
  "España",
  "Buenos Aires",
  "Los Aromos",
  "Los Pinos",
];

function extractPii(data) {
  const pii = {};
  const deletes = {};
  if (!data || typeof data !== "object") return { pii, deletes };
  for (const k of PII_KEYS) {
    if (Object.prototype.hasOwnProperty.call(data, k) && data[k] !== undefined) {
      pii[k] = data[k];
      deletes[k] = admin.firestore.FieldValue.delete();
    }
  }
  return { pii, deletes };
}

async function loadMerged(uid) {
  const db = admin.firestore();
  const ref = db.collection("usuarios").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) return { ref, snap, parent: null, pii: {}, merged: null };
  const parent = snap.data() || {};
  let pii = {};
  try {
    const priv = await ref.collection("privado").doc("identidad").get();
    if (priv.exists) pii = priv.data() || {};
  } catch (_) {}
  return { ref, snap, parent, pii, merged: { ...parent, ...pii } };
}

async function mergePii(ref, parentData) {
  let pii = {};
  try {
    const priv = await ref.collection("privado").doc("identidad").get();
    if (priv.exists) pii = priv.data() || {};
  } catch (_) {}
  return { ...parentData, ...pii };
}

function sanitizarOps(parentData) {
  const { pii, deletes } = extractPii(parentData);
  if (!Object.keys(pii).length) return null;
  pii.updated_at = admin.firestore.FieldValue.serverTimestamp();
  return { pii, deletes };
}

function domicilioRealDe(merged) {
  if (!merged) return null;
  const calle = String(merged.calle || "").trim();
  const numero = String(merged.numero || "").trim();
  const geo = merged.direccion_geo || {};
  const loc = String(geo.localidad_nombre || "").trim() || "Localidad desconocida";
  if (!calle || !numero) return null;
  return `${calle} ${numero}, ${loc}`;
}

function localidadDeDomicilio(domicilio) {
  const i = String(domicilio).lastIndexOf(",");
  if (i < 0) return "Buenos Aires";
  const loc = String(domicilio).slice(i + 1).trim();
  return loc || "Buenos Aires";
}

function shuffleInPlace(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const t = arr[i];
    arr[i] = arr[j];
    arr[j] = t;
  }
  return arr;
}

function domiciliosSenuelo(real) {
  const loc = localidadDeDomicilio(real);
  const calles = CALLES_SENUELO.slice();
  shuffleInPlace(calles);
  const out = [];
  for (const calle of calles) {
    const n = 40 + Math.floor(Math.random() * 4600);
    const fake = `${calle} ${n}, ${loc}`;
    if (fake === real || out.includes(fake)) continue;
    out.push(fake);
    if (out.length >= 2) break;
  }
  return out;
}

function opcionesQuiz(real) {
  const opciones = [real, ...domiciliosSenuelo(real)];
  let guard = 0;
  while (opciones.length < 3 && guard < 8) {
    for (const extra of domiciliosSenuelo(`${real}-${guard}`)) {
      if (!opciones.includes(extra)) opciones.push(extra);
      if (opciones.length >= 3) break;
    }
    guard++;
  }
  shuffleInPlace(opciones);
  return opciones.slice(0, 3);
}

function nombreDe(merged) {
  const n = `${merged?.nombre || ""} ${merged?.apellido || ""}`.trim();
  return n || "esta persona";
}

module.exports = {
  PII_KEYS,
  extractPii,
  loadMerged,
  mergePii,
  sanitizarOps,
  domicilioRealDe,
  opcionesQuiz,
  nombreDe,
};
