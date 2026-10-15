/**
 * Entrypoint de Cloud Functions (package.json "main").
 *
 * Qué hace: fija los defaults de todas las funciones y reexporta los handlers
 * de los módulos. No contiene lógica de negocio.
 *
 * Defaults para callables livianos: us-east1, 256 MiB, 60 s, máximo 5
 * instancias. Sin mínimo de instancias (no queda nada encendido al pedo).
 *
 * El batch de scoring NO usa este default: cf_scoring_http.js declara
 * 1 GiB, 540 s y 1 instancia. Fiados y oficios libres también se sobreescriben
 * en su propio archivo.
 *
 * index_impl.js no se carga. No es fuente. Si este archivo queda truncado
 * (SEE_FILE / PLACEHOLDER) el deploy pierde funciones en silencio:
 * functions/check_exports.js lo frena antes de publicar.
 *
 * assignSafe traga un módulo que no carga para no tumbar el proceso al
 * arrancar. El guard de CI exige igual que los exports críticos existan.
 */
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({
  region: "us-east1",
  memory: "256MiB",
  timeoutSeconds: 60,
  maxInstances: 5,
});

function isCfHandler(v) {
  return !!(v && typeof v === "function" && (v.__endpoint || v.run));
}

function assignSafe(modPath) {
  try {
    const m = require(modPath);
    if (!m || typeof m !== "object") return;
    for (const [k, v] of Object.entries(m)) {
      if (isCfHandler(v)) exports[k] = v;
    }
  } catch (e) {
    console.error("cf module skip", modPath, e && e.message);
  }
}

assignSafe("./cf_scoring_http");
assignSafe("./cf_validacion");
assignSafe("./cf_vault");
assignSafe("./cf_recibo");
assignSafe("./cf_fiados_sched");
assignSafe("./cf_pii_sanitize");
assignSafe("./cf_oficios_libres_sched");
assignSafe("./cf_cuenta");

exports.enviarMensajeTexto = require("./mensajes_texto").enviarMensajeTexto;
const calificacionAviso = require("./calificacion_aviso");
exports.avisarCalificacionPrestador = calificacionAviso.avisarCalificacionPrestador;
exports.responderCalificacion = calificacionAviso.responderCalificacion;
const authEmails = require("./auth_emails");
exports.sendAuthEmail = authEmails.sendAuthEmail;
exports.enviarMensajeDesarrollador = authEmails.enviarMensajeDesarrollador;
exports.obtenerContactoPrestador = require("./contacto_prestador").obtenerContactoPrestador;
const tarjetaShare = require("./tarjeta_share");
exports.crearTarjetaShare = tarjetaShare.crearTarjetaShare;
exports.sanitizarTarjetasShare = tarjetaShare.sanitizarTarjetasShare;
