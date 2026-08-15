/**
 * Batch: fiados con fecha de cobro vencida o de hoy → push FCM al dueño.
 *
 * Campos en claro en usuarios/{uid}/fiados (no cifrados):
 *   estado, vto_dia (yyyy-MM-dd), notificado_vto_dia, owner_uid
 */
const admin = require("firebase-admin");

function todayYmd(timeZone = "America/Argentina/Buenos_Aires") {
  // en-CA → yyyy-mm-dd
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

async function tokensForUid(db, uid) {
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

async function sendToTokens(tokens, payload) {
  if (!tokens.length) return { success: 0, failure: 0, noToken: true };
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: {
      type: "fiado_vto",
      open: "me_deben",
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
}

/**
 * @param {{ force?: boolean }} opts
 */
async function runFiadosVtoBatch(opts = {}) {
  const db = admin.firestore();
  const force = !!opts.force;
  const hoy = todayYmd();
  const started = Date.now();

  // collectionGroup: todos los fiados pendientes con vto_dia <= hoy
  let query = db
    .collectionGroup("fiados")
    .where("estado", "==", "pendiente")
    .where("vto_dia", "<=", hoy);

  const snap = await query.get();

  let scanned = 0;
  let candidates = 0;
  let notifiedUsers = 0;
  let pushOk = 0;
  let pushFail = 0;
  let skippedAlready = 0;
  let noToken = 0;
  const byUid = new Map(); // uid -> count de fiados a avisar

  for (const doc of snap.docs) {
    scanned++;
    const data = doc.data() || {};
    const vto = data.vto_dia;
    if (!vto || typeof vto !== "string") continue;

    // path: usuarios/{uid}/fiados/{id}
    const parts = doc.ref.path.split("/");
    const uidIdx = parts.indexOf("usuarios");
    const uid =
      data.owner_uid ||
      (uidIdx >= 0 && parts[uidIdx + 1] ? parts[uidIdx + 1] : null);
    if (!uid) continue;

    if (!force && data.notificado_vto_dia === hoy) {
      skippedAlready++;
      continue;
    }

    candidates++;
    byUid.set(uid, (byUid.get(uid) || 0) + 1);

    // Marcar notificado del día (idempotente por día)
    try {
      await doc.ref.set(
        {
          notificado_vto_dia: hoy,
          notificado_vto_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (e) {
      console.warn("mark notificado", doc.ref.path, e.message || e);
    }
  }

  for (const [uid, count] of byUid.entries()) {
    const tokens = await tokensForUid(db, uid);
    const title = "Me deben · cobro pendiente";
    const body =
      count === 1
        ? "Tenés 1 fiado con fecha de cobro para hoy o vencida. Revisá Me deben."
        : `Tenés ${count} fiados con fecha de cobro para hoy o vencida. Revisá Me deben.`;

    const sendRes = await sendToTokens(tokens, { title, body });
    if (sendRes.noToken) {
      noToken++;
      console.log("fiadosVto no token", uid, count);
    } else {
      notifiedUsers++;
      pushOk += sendRes.success;
      pushFail += sendRes.failure;
    }
  }

  const result = {
    ok: true,
    hoy,
    scanned,
    candidates,
    users: byUid.size,
    notifiedUsers,
    pushOk,
    pushFail,
    noToken,
    skippedAlready,
    ms: Date.now() - started,
  };
  console.log("runFiadosVtoBatch", result);
  return result;
}

module.exports = { runFiadosVtoBatch, todayYmd };
