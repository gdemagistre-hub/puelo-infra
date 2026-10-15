/**
 * Guard de CI para el entrypoint functions/index.js.
 *
 * Qué hace: rechaza un index.js truncado (SEE_FILE / PLACEHOLDER) y exige
 * que el assembler exporte los handlers que la app y el scheduler usan.
 * Corre antes del deploy (deploy-functions.yml y ci-functions-guard.yml).
 *
 * No es una Cloud Function. index.js no lo carga.
 */
"use strict";

const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const indexPath = path.join(__dirname, "index.js");
const src = fs.readFileSync(indexPath, "utf8");
const code = src.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");

if (/SEE_FILE|PLACEHOLDER/.test(code)) {
  console.error("index.js contiene SEE_FILE o PLACEHOLDER fuera de comentarios");
  process.exit(1);
}

execFileSync(process.execPath, ["--check", indexPath], { stdio: "inherit" });

const REQUIRED = [
  "scoringBatchHttp",
  "scoringBatchDaily",
  "previewValidacionPendiente",
  "submitValidacionPendiente",
  "aplicarValidacionPendiente",
  "registerVaultRecovery",
  "recoverVaultDek",
  "emitirRecibo",
  "responderRecibo",
  "fiadosVtoDaily",
  "fiadosVtoEvening",
  "fiadosVtoHttp",
  "sanitizarTelefonoPublico",
  "oficiosLibresDaily",
  "oficiosLibresAhora",
  "solicitarEliminacionCuenta",
  "enviarMensajeTexto",
  "avisarCalificacionPrestador",
  "responderCalificacion",
  "sendAuthEmail",
  "enviarMensajeDesarrollador",
  "obtenerContactoPrestador",
  "crearTarjetaShare",
  "sanitizarTarjetasShare",
];

const exported = require("./index.js");
const missing = REQUIRED.filter((name) => typeof exported[name] !== "function");
if (missing.length) {
  console.error("Faltan exports de Cloud Functions:", missing.join(", "));
  process.exit(1);
}

console.log("functions guard ok:", REQUIRED.length, "exports");
