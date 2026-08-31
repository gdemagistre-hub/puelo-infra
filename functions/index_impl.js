/**
 * Assembler Cloud Functions. setGlobalOptions una sola vez.
 */
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({
  region: "us-east1",
  memory: "1GiB",
  timeoutSeconds: 540,
});

Object.assign(exports, require("./cf_scoring_http"));
Object.assign(exports, require("./cf_validacion"));
Object.assign(exports, require("./cf_vault"));
Object.assign(exports, require("./cf_recibo"));
Object.assign(exports, require("./cf_fiados_sched"));

exports.enviarMensajeTexto = require("./mensajes_texto").enviarMensajeTexto;
const calificacionAviso = require("./calificacion_aviso");
exports.avisarCalificacionPrestador = calificacionAviso.avisarCalificacionPrestador;
exports.responderCalificacion = calificacionAviso.responderCalificacion;
exports.sendAuthEmail = require("./auth_emails").sendAuthEmail;
exports.obtenerContactoPrestador = require("./contacto_prestador").obtenerContactoPrestador;
exports.crearTarjetaShare = require("./tarjeta_share").crearTarjetaShare;
