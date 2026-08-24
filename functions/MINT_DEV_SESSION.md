mintDevSession se retira por impersonación (custom token + secreto en cliente).

Estado 2026-08-24:
- Cliente: ya no llama el endpoint (loginScreen).
- Rules: rechazan claim dev_impersonation.
- Functions: borrar exports.mintDevSession en index.js y redeploy.
- Consola GCP: destruir secret DEV_LOGIN_SECRET cuando el export ya no exista.
