/**
 * Digest de oficio_libre → dev@puelo.app (sin teléfono, DNI ni email de usuarios).
 * Cron 08:10 ART. Si no hay libres, no manda mail.
 */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

const FROM_EMAIL = "no-reply@puelo.app";
const TO_EMAIL = "dev@puelo.app";
const PAGE = 400;

function requireAdmin(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Necesitás sesión");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Solo admin");
  }
}

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
    auth: { user: FROM_EMAIL, pass },
  });
}

function norm(s) {
  return String(s || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

async function recolectarLibres() {
  const db = admin.firestore();
  const snap = await db.collection("usuarios").limit(PAGE).get();
  const byKey = new Map();
  let scanned = 0;
  for (const doc of snap.docs) {
    scanned += 1;
    const d = doc.data() || {};
    const raw = String(d.oficio_libre || "").trim();
    if (!raw) continue;
    const country = String(d.country_code || "AR").toUpperCase();
    const key = `${country}|${norm(raw)}`;
    const prev = byKey.get(key) || {
      country,
      label: raw.slice(0, 80),
      n: 0,
      uids: [],
    };
    prev.n += 1;
    if (prev.uids.length < 3) prev.uids.push(doc.id);
    byKey.set(key, prev);
  }
  const items = Array.from(byKey.values()).sort((a, b) => b.n - a.n);
  return { scanned, items };
}

function htmlDigest(items, scanned) {
  const rows = items
    .map(
      (it) =>
        `<tr>
          <td style="padding:6px 10px;border-bottom:1px solid #e2e8f0">${it.country}</td>
          <td style="padding:6px 10px;border-bottom:1px solid #e2e8f0">${it.label}</td>
          <td style="padding:6px 10px;border-bottom:1px solid #e2e8f0">${it.n}</td>
        </tr>`
    )
    .join("");
  return `<!DOCTYPE html><html><body style="font-family:system-ui,sans-serif;color:#0f172a">
  <div style="max-width:640px;margin:24px auto">
    <h2 style="color:#28B5CD">Oficios libres (${items.length})</h2>
    <p style="color:#64748b;font-size:13px">Perfiles mirados: ${scanned}. Sin PII de contacto.
    Sirve para mapear al catálogo o descartar (ej. fuera de marketplace).</p>
    <table style="border-collapse:collapse;width:100%;font-size:14px">
      <thead><tr>
        <th align="left">País</th><th align="left">Texto</th><th align="left">N</th>
      </tr></thead>
      <tbody>${rows}</tbody>
    </table>
  </div></body></html>`;
}

async function runDigest() {
  const { scanned, items } = await recolectarLibres();
  const db = admin.firestore();
  await db.collection("stats").doc("oficios_libres").set(
    {
      last_run_at: admin.firestore.FieldValue.serverTimestamp(),
      scanned,
      distinct: items.length,
      sample: items.slice(0, 40).map((it) => ({
        country: it.country,
        label: it.label,
        n: it.n,
      })),
    },
    { merge: true }
  );
  if (!items.length) {
    return { ok: true, emailed: false, scanned, distinct: 0 };
  }
  const transport = getTransport();
  await transport.sendMail({
    from: `Puelo <${FROM_EMAIL}>`,
    to: TO_EMAIL,
    subject: `[Puelo] ${items.length} oficios libres para revisar`,
    html: htmlDigest(items, scanned),
  });
  return { ok: true, emailed: true, scanned, distinct: items.length };
}

exports.oficiosLibresDaily = onSchedule(
  {
    schedule: "10 8 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
    region: "us-east1",
    memory: "256MiB",
    timeoutSeconds: 120,
    secrets: ["IONOS_SMTP_PASS"],
  },
  async () => {
    const out = await runDigest();
    console.log("oficiosLibresDaily", out);
    return out;
  }
);

exports.oficiosLibresAhora = onCall(
  {
    cors: true,
    region: "us-east1",
    memory: "256MiB",
    timeoutSeconds: 120,
    secrets: ["IONOS_SMTP_PASS"],
  },
  async (request) => {
    requireAdmin(request);
    return runDigest();
  }
);
