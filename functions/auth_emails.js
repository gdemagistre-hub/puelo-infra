/**
 * Auth emails desde no-reply@puelo.app via SMTP IONOS.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

const FROM_EMAIL = "no-reply@puelo.app";
const FROM = `Puelo <${FROM_EMAIL}>`;
const CONTINUE_URL = "https://lifewalletpuelo.web.app/";

const actionCodeSettings = {
  url: CONTINUE_URL,
  handleCodeInApp: false,
};

function htmlVerify(link) {
  return `<!DOCTYPE html><html><body style="font-family:system-ui,sans-serif;line-height:1.5;color:#0f172a">
  <div style="max-width:520px;margin:24px auto;padding:24px;border:1px solid #e2e8f0;border-radius:12px">
    <h2 style="margin:0 0 12px;color:#28B5CD">Confirmá tu email en Puelo</h2>
    <p>Para activar tu cuenta, tocá el botón:</p>
    <p style="text-align:center;margin:28px 0">
      <a href="${link}" style="background:#28B5CD;color:#fff;padding:12px 22px;border-radius:10px;text-decoration:none;font-weight:700">Verificar email</a>
    </p>
    <p style="font-size:13px;color:#64748b">Si el botón no funciona, copiá este enlace:<br/>
    <a href="${link}" style="color:#28B5CD;word-break:break-all">${link}</a></p>
  </div></body></html>`;
}

function htmlReset(link) {
  return `<!DOCTYPE html><html><body style="font-family:system-ui,sans-serif;line-height:1.5;color:#0f172a">
  <div style="max-width:520px;margin:24px auto;padding:24px;border:1px solid #e2e8f0;border-radius:12px">
    <h2 style="margin:0 0 12px;color:#734BE4">Restablecer contraseña</h2>
    <p>Recibimos un pedido para cambiar la contraseña de tu cuenta Puelo.</p>
    <p style="text-align:center;margin:28px 0">
      <a href="${link}" style="background:#734BE4;color:#fff;padding:12px 22px;border-radius:10px;text-decoration:none;font-weight:700">Elegir nueva contraseña</a>
    </p>
  </div></body></html>`;
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

async function sendMail({ to, subject, html }) {
  const transport = getTransport();
  const info = await transport.sendMail({ from: FROM, to, subject, html });
  console.log("auth email sent", { to, messageId: info.messageId });
  return info;
}

exports.sendAuthEmail = onCall(
  { region: "us-east1", secrets: ["IONOS_SMTP_PASS"], memory: "256MiB", timeoutSeconds: 30 },
  async (request) => {
    const type = String(request.data?.type || "").trim();
    if (type !== "verify" && type !== "reset") {
      throw new HttpsError("invalid-argument", "type debe ser verify o reset");
    }
    try {
      if (type === "verify") {
        if (!request.auth?.uid) {
          throw new HttpsError("unauthenticated", "Iniciá sesión para reenviar la verificación");
        }
        const user = await admin.auth().getUser(request.auth.uid);
        if (!user.email) throw new HttpsError("failed-precondition", "La cuenta no tiene email");
        if (user.emailVerified) return { ok: true, skipped: true, reason: "already_verified" };
        const link = await admin.auth().generateEmailVerificationLink(user.email, actionCodeSettings);
        await sendMail({ to: user.email, subject: "Confirmá tu email en Puelo", html: htmlVerify(link) });
        return { ok: true, via: "ionos-smtp", from: FROM_EMAIL };
      }
      const email = String(request.data?.email || "").trim().toLowerCase();
      if (!email || !email.includes("@")) throw new HttpsError("invalid-argument", "Email inválido");
      try {
        const link = await admin.auth().generatePasswordResetLink(email, actionCodeSettings);
        await sendMail({ to: email, subject: "Restablecer contraseña — Puelo", html: htmlReset(link) });
      } catch (e) {
        console.warn("sendAuthEmail reset:", e?.code || e?.message || e);
      }
      return { ok: true, via: "ionos-smtp", from: FROM_EMAIL };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      if (e?.code === "no_smtp_pass") {
        throw new HttpsError("failed-precondition", "IONOS_SMTP_PASS no configurada");
      }
      console.error("sendAuthEmail", e);
      throw new HttpsError("internal", e?.message || "No se pudo enviar el email");
    }
  }
);

function escapeHtmlDev(s) {
  return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function ymdArt(d = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Argentina/Buenos_Aires",
    year: "numeric", month: "2-digit", day: "2-digit",
  }).format(d);
}

exports.enviarMensajeDesarrollador = onCall(
  { region: "us-east1", secrets: ["IONOS_SMTP_PASS"], memory: "256MiB", timeoutSeconds: 30 },
  async (request) => {
    try {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError("unauthenticated", "Iniciá sesión para continuar.");
      }
      const uid = request.auth.uid;
      const mensaje = String((request.data && request.data.mensaje) || "").trim();
      if (!mensaje) throw new HttpsError("invalid-argument", "Escribí un mensaje.");
      if (mensaje.length > 800) throw new HttpsError("invalid-argument", "El mensaje no puede superar 800 caracteres.");
      const email = String((request.auth.token && request.auth.token.email) || "").slice(0, 120);
      const db = admin.firestore();
      const rateRef = db.collection("usuarios").doc(uid).collection("privado").doc("rate_dev_mensaje");
      const hoy = ymdArt();
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(rateRef);
        const data = snap.exists ? snap.data() || {} : {};
        const n = String(data.dia || "") === hoy ? Number(data.n || 0) || 0 : 0;
        if (n >= 5) throw new HttpsError("resource-exhausted", "Ya enviaste varios mensajes hoy. Probá mañana.");
        tx.set(rateRef, { dia: hoy, n: n + 1, updated_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      });
      const inboxRef = db.collection("dev_inbox").doc();
      await inboxRef.set({
        uid, email: email || null, mensaje,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        mailed: false, source: "enviarMensajeDesarrollador",
      });
      let mailed = false;
      try {
        await sendMail({
          to: "dev@puelo.app",
          subject: "[Puelo] Mensaje al desarrollador (" + uid.slice(0, 8) + ")",
          html: "<p>uid: " + escapeHtmlDev(uid) + "<br/>email: " + escapeHtmlDev(email || "(sin email)") + "</p><pre>" + escapeHtmlDev(mensaje) + "</pre>",
        });
        mailed = true;
        await inboxRef.set({ mailed: true, mailed_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      } catch (e) {
        console.error("enviarMensajeDesarrollador mail", e && e.message);
        await inboxRef.set({ mail_error: String((e && e.message) || e).slice(0, 220) }, { merge: true });
      }
      return { ok: true, mailed };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("enviarMensajeDesarrollador", e);
      throw new HttpsError("unavailable", "No se pudo enviar el mensaje. Probá más tarde.");
    }
  }
);
