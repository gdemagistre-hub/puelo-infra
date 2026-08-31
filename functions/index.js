/**
 * Cloud Functions assembler — Puelo
 * 2026-08-31 S1: validación en cf_validacion (sin calle en calificaciones).
 */
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({
  region: "us-east1",
  memory: "1GiB",
  timeoutSeconds: 540,
});

function assignSafe(modPath) {
  try {
    const m = require(modPath);
    if (m && typeof m === "object") Object.assign(exports, m);
  } catch (e) {
    console.error("cf module skip", modPath, e && e.message);
  }
}

assignSafe("./cf_scoring_http");
assignSafe("./cf_validacion");
assignSafe("./cf_vault");
assignSafe("./cf_recibo");
assignSafe("./cf_fiados_sched");

exports.enviarMensajeTexto = require("./mensajes_texto").enviarMensajeTexto;
const calificacionAviso = require("./calificacion_aviso");
exports.avisarCalificacionPrestador = calificacionAviso.avisarCalificacionPrestador;
exports.responderCalificacion = calificacionAviso.responderCalificacion;
exports.sendAuthEmail = require("./auth_emails").sendAuthEmail;
exports.obtenerContactoPrestador = require("./contacto_prestador").obtenerContactoPrestador;
exports.crearTarjetaShare = require("./tarjeta_share").crearTarjetaShare;
