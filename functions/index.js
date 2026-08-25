/**
 * Cloud Functions — Puelo (lifewalletpuelo)
 * 2026-08-24: mintDevSession eliminado; submit+aplicar validación exigen Auth real.
 * 2026-08-24 etapa vault: VAULT_RECOVERY_SECRET obligatorio (fail-closed).
 * 2026-08-24 etapa A2: HMAC de comprobante sin texto de respaldo (fail-closed).
 * 2026-08-24 etapa A4b: export obtenerContactoPrestador.
 */
module.exports = require("./index_impl");
