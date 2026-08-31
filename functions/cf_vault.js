const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { admin, db, crypto, requireAuthUid } = require("./cf_shared");

function requireVaultRecoverySecret() {
  const secret = String(process.env.VAULT_RECOVERY_SECRET || "").trim();
  if (!secret) {
    throw new HttpsError(
      "unavailable",
      "Recuperación de bóveda no disponible"
    );
  }
  return secret;
}

function recoveryKeyFor(uid) {
  const secret = requireVaultRecoverySecret();
  return crypto.createHash("sha256").update(`${secret}:${uid}`).digest();
}

function wrapDek(dekBuf, uid) {
  const key = recoveryKeyFor(uid);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(dekBuf), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([Buffer.from([1]), iv, tag, enc]).toString("base64");
}

function unwrapDek(packedB64, uid) {
  const raw = Buffer.from(packedB64, "base64");
  if (raw.length < 1 + 12 + 16 || raw[0] !== 1) {
    throw new Error("Formato recovery inválido");
  }
  const iv = raw.subarray(1, 13);
  const tag = raw.subarray(13, 29);
  const enc = raw.subarray(29);
  const key = recoveryKeyFor(uid);
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]);
}

exports.registerVaultRecovery = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: ["VAULT_RECOVERY_SECRET"],
  },
  async (request) => {
    requireVaultRecoverySecret();
    const uid = requireAuthUid(request);
    const dekBase64 = request.data && request.data.dekBase64;
    if (!dekBase64 || typeof dekBase64 !== "string") {
      throw new HttpsError("invalid-argument", "dekBase64 requerido");
    }
    let dekBuf;
    try {
      dekBuf = Buffer.from(dekBase64, "base64");
    } catch (e) {
      throw new HttpsError("invalid-argument", "dekBase64 inválido");
    }
    if (dekBuf.length < 16 || dekBuf.length > 64) {
      throw new HttpsError("invalid-argument", "DEK de tamaño inválido");
    }
    const wrapped = wrapDek(dekBuf, uid);
    await db.collection("usuarios").doc(uid).collection("vault").doc("meta").set(
      {
        dek_wrapped_recovery: wrapped,
        recovery_v: 1,
        recoveryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { ok: true };
  }
);

exports.recoverVaultDek = onCall(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: ["VAULT_RECOVERY_SECRET"],
  },
  async (request) => {
    requireVaultRecoverySecret();
    const uid = requireAuthUid(request);
    const snap = await db.collection("usuarios").doc(uid).collection("vault").doc("meta").get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "No hay bóveda");
    }
    const wrapped = snap.get("dek_wrapped_recovery");
    if (!wrapped || typeof wrapped !== "string") {
      throw new HttpsError(
        "failed-precondition",
        "Esta bóveda no tiene recuperación. Podés empezar de cero."
      );
    }
    try {
      const dekBuf = unwrapDek(wrapped, uid);
      return { dekBase64: dekBuf.toString("base64") };
    } catch (e) {
      console.error("unwrap recovery", e);
      throw new HttpsError("internal", "No se pudo recuperar la clave");
    }
  }
);
