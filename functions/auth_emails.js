/**
 * Auth emails desde dominio propio (no-reply@puelo.app) vía Resend.
 *
 * Setup owner (una vez):
 * 1) Cuenta Resend → verificar dominio puelo.app (SPF/DKIM/DMARC que indique Resend)
 * 2) firebase functions:secrets:set RESEND_API_KEY --project lifewalletpuelo
 * 3) En este archivo, agregar secrets: ["RESEND_API_KEY"] al onCall y redeploy
 *    (sin el binding, process.env.RESEND_API_KEY no llega a runtime)
 *
 * Mientras no haya key, el cliente usa el mail default de Firebase Auth.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const FROM = "Puelo <no-reply@puelo.app>";
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
    <p style="font-size:12px;color:#94a3b8;margin-top:24px">Puelo · este mail no recibe respuestas (no-reply@puelo.app)</p>
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
    <p style="font-size:12px;color:#94a3b8;margin-top:24px">Puelo · no-reply@puelo.app</p>
  </div></body></html>`;
}

async function sendResend({ to, subject, html }) {
  const key = process.env.RESEND_API_KEY || "";
  if (!key) {
    const err = new Error("RESEND_API_KEY not configured");
    err.code = "no_resend_key";
    throw err;
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM,
      to: [to],
      subject,
      html,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error("Resend error", res.status, body);
    const err = new Error(body.message || `Resend HTTP ${res.status}`);
    err.code = "resend_failed";
    throw err;
  }
  return body;
}

/**
 * Callable: { type: 'verify' | 'reset', email?: string }
 * - verify: requiere Auth; usa email del token
 * - reset: email obligatorio; no revela si existe la cuenta
 *
 * TEMP: sin secrets:[] para no bloquear deploy. Tras crear RESEND_API_KEY:
 *   secrets: ["RESEND_API_KEY"]  + redeploy.
 */
exports.sendAuthEmail = onCall(
  {
    region: "us-east1",
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
        await sendResend({
          to: user.email,
          subject: "Confirmá tu email en Puelo",
          html: htmlVerify(link),
        });
        return { ok: true, via: "resend", from: "no-reply@puelo.app" };
      }

      // reset
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
        await sendResend({
          to: email,
          subject: "Restablecer contraseña — Puelo",
          html: htmlReset(link),
        });
      } catch (e) {
        // No filtrar existencia de cuenta (anti-enumeration).
        console.warn("sendAuthEmail reset:", e?.code || e?.message || e);
      }
      return { ok: true, via: "resend", from: "no-reply@puelo.app" };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      if (e?.code === "no_resend_key") {
        throw new HttpsError(
          "failed-precondition",
          "RESEND_API_KEY no configurada — usar fallback cliente"
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
