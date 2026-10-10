/**
 * Cierra el día anterior (ART) en stats/plaza_diaria/dias/{yyyymmdd}.
 * Lo corre scoringBatchDaily (02:30 ART). No exporta un handler nuevo.
 */
const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();

const { UID_RE, buildPlazaDoc } = require("./plaza_agg");

function ymdArt(date) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Argentina/Buenos_Aires",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .format(date)
    .replace(/-/g, "");
}

function startOfArtDay(ymd) {
  const y = ymd.slice(0, 4);
  const m = ymd.slice(4, 6);
  const d = ymd.slice(6, 8);
  return new Date(`${y}-${m}-${d}T00:00:00-03:00`);
}

function millisOf(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate().getTime();
  if (v instanceof Date) return v.getTime();
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const t = Date.parse(v);
    return Number.isNaN(t) ? null : t;
  }
  return null;
}

async function eachPage(baseQuery, onDoc, cap) {
  let last = null;
  let n = 0;
  const limit = 400;
  while (n < cap) {
    let q = baseQuery.limit(limit);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      n += 1;
      onDoc(doc);
      if (n >= cap) break;
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < limit) break;
  }
  return n;
}

async function runPlazaAyer(opts = {}) {
  const db = opts.db || admin.firestore();
  const ymd =
    opts.ymd || ymdArt(new Date(Date.now() - 24 * 60 * 60 * 1000));
  const start = startOfArtDay(ymd);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  const startMs = start.getTime();
  const endMs = end.getTime();
  const startTs = admin.firestore.Timestamp.fromDate(start);
  const endTs = admin.firestore.Timestamp.fromDate(end);

  const users = [];
  await eachPage(db.collection("usuarios").orderBy(admin.firestore.FieldPath.documentId()), (doc) => {
    const data = doc.data() || {};
    if (data.cuenta_eliminada === true) return;
    users.push({
      id: doc.id,
      creadoMs: millisOf(data.creado_en),
      data,
    });
  }, 8000);

  const demanda = [];
  await eachPage(
    db
      .collection("demanda_eventos")
      .where("created_at", ">=", startTs)
      .where("created_at", "<", endTs)
      .orderBy("created_at"),
    (doc) => {
      const data = doc.data() || {};
      demanda.push({ id: doc.id, oficio_id: data.oficio_id });
    },
    4000
  );

  const contactos = [];
  await eachPage(
    db
      .collection("contactos")
      .where("created_at", ">=", startTs)
      .where("created_at", "<", endTs)
      .orderBy("created_at"),
    (doc) => {
      const data = doc.data() || {};
      contactos.push({
        cliente_uid: data.cliente_uid,
        origen: data.origen,
        tipo: data.tipo,
      });
    },
    4000
  );

  const analytics = [];
  try {
    await eachPage(
      db
        .collection("analytics_events")
        .where("ts", ">=", startTs)
        .where("ts", "<", endTs)
        .orderBy("ts"),
      (doc) => {
        const data = doc.data() || {};
        analytics.push({
          id: doc.id,
          type: data.type,
          role: data.role,
          name: data.name,
          guest: data.guest === true,
          uid: data.uid,
          session_id: data.session_id,
        });
      },
      4000
    );
  } catch (e) {
    console.error("plaza analytics", String(e.message || e).slice(0, 160));
  }

  let comprobantes = 0;
  try {
    await eachPage(
      db
        .collection("conversaciones")
        .where("last_event_at", ">=", startTs)
        .where("last_event_at", "<", endTs)
        .orderBy("last_event_at"),
      (doc) => {
        const data = doc.data() || {};
        if (data.last_recibo_decision === "aceptado") comprobantes += 1;
      },
      2000
    );
  } catch (e) {
    console.error("plaza comprobantes", String(e.message || e).slice(0, 160));
  }

  const payload = buildPlazaDoc({
    ymd,
    startMs,
    endMs,
    users,
    demanda,
    contactos,
    analytics,
    comprobantes,
  });
  payload.actualizado_en = admin.firestore.FieldValue.serverTimestamp();

  await db
    .collection("stats")
    .doc("plaza_diaria")
    .collection("dias")
    .doc(ymd)
    .set(payload);

  return {
    status: "ok",
    ymd,
    altas: payload.altas,
    busquedas: payload.busquedas,
    contactos: payload.contactos,
    comprobantes: payload.comprobantes_confirmados,
    salto_n: payload.salto_n,
    invitados: payload.invitados,
    zonas: Object.keys(payload.zonas).length,
    usuarios_leidos: users.length,
    uid_ok: UID_RE.source.length > 0,
  };
}

module.exports = { runPlazaAyer, ymdArt };
