/**
 * Auth emails desde no-reply@puelo.app vía SMTP IONOS.
 *
 * Setup owner:
 * 1) Casilla no-reply@puelo.app en IONOS (ya hecha)
 * 2) firebase functions:secrets:set IONOS_SMTP_PASS --project lifewalletpuelo
 *    (pegar la contraseña del buzón; no se muestra al tipear)
 * 3) Redeploy functions
 *
 * SMTP IONOS (oficial):
 *   host: smtp.ionos.com
 *   port: 587  STARTTLS
 *   user: no-reply@puelo.app
 *
 * Sin IONOS_SMTP_PASS el cliente cae al mail default de Firebase Auth.
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
    <p style="font-size:12px;color:#94a3b8;margin-top:24px">Puelo · este mail no recibe respuestas (${FROM_EMAIL})</p>
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
    <p style="font-size:13px;color:#64748b">Si no pediste esto, ignorá el mail. El enlace vence en unas horas.</p>
    <p style="font-size:12px;color:#94a3b8;margin-top:24px">Puelo · ${FROM_EMAIL}</p>
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
    secure: false, // STARTTLS
    auth: {
      user: FROM_EMAIL,
      pass,
    },
  });
}

async function sendMail({ to, subject, html }) {
  const transport = getTransport();
  const info = await transport.sendMail({
    from: FROM,
    to,
    subject,
    html,
  });
  console.log("auth email sent", { to, messageId: info.messageId });
  return info;
}

/**
 * Callable: { type: 'verify' | 'reset', email?: string }
 */
exports.sendAuthEmail = onCall(
  {
    region: "us-east1",
    secrets: ["IONOS_SMTP_PASS"],
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (request) => {
    const type = String(request.data?.type || "").trim();
    if (type !== "verify" && type !== "reset") {
      throw new HttpsError("invalid-argument", "type debe ser verify o reset");
    }

    try {
      if (type === "verify") {
        if (!request.auth?.uid) {
          throw new HttpsError(
            "unauthenticated",
            "Iniciá sesión para reenviar la verificación"
          );
        }
        const user = await admin.auth().getUser(request.auth.uid);
        if (!user.email) {
          throw new HttpsError("failed-precondition", "La cuenta no tiene email");
        }
        if (user.emailVerified) {
          return { ok: true, skipped: true, reason: "already_verified" };
        }
        const link = await admin
          .auth()
          .generateEmailVerificationLink(user.email, actionCodeSettings);
        await sendMail({
          to: user.email,
          subject: "Confirmá tu email en Puelo",
          html: htmlVerify(link),
        });
        return { ok: true, via: "ionos-smtp", from: FROM_EMAIL };
      }

      const email = String(request.data?.email || "")
        .trim()
        .toLowerCase();
      if (!email || !email.includes("@")) {
        throw new HttpsError("invalid-argument", "Email inválido");
      }
      try {
        const link = await admin
          .auth()
          .generatePasswordResetLink(email, actionCodeSettings);
        await sendMail({
          to: email,
          subject: "Restablecer contraseña — Puelo",
          html: htmlReset(link),
        });
      } catch (e) {
        console.warn("sendAuthEmail reset:", e?.code || e?.message || e);
      }
      return { ok: true, via: "ionos-smtp", from: FROM_EMAIL };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      if (e?.code === "no_smtp_pass") {
        throw new HttpsError(
          "failed-precondition",
          "IONOS_SMTP_PASS no configurada — usar fallback cliente"
        );
      }
      console.error("sendAuthEmail", e);
      throw new HttpsError(
        "internal",
        e?.message || "No se pudo enviar el email"
      );
    }
  }
);
