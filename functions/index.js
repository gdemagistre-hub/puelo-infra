/**
 * Cloud Functions entrypoints — Puelo scoring batch.
 * Lógica en scoringCore.js
 */
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const { runScoringBatch } = require("./scoringCore");

setGlobalOptions({
  region: "southamerica-east1",
  memory: "1GiB",
  timeoutSeconds: 540,
});

/** HTTP: POST/GET con header X-Batch-Secret o ?secret= */
exports.scoringBatchHttp = onRequest({ invoker: "public" }, async (req, res) => {
  if (req.method !== "POST" && req.method !== "GET") {
    res.status(405).send("Method not allowed");
    return;
  }
  const secret = process.env.BATCH_SECRET || "";
  const provided =
    req.get("X-Batch-Secret") || req.query.secret || (req.body && req.body.secret) || "";
  if (secret && provided !== secret) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  const force = req.query.force === "1" || (req.body && req.body.force === true);
  const trigger = req.query.trigger || (req.body && req.body.trigger) || "http";
  try {
    const result = await runScoringBatch({ trigger, force });
    res.status(200).json(result);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e.message || e) });
  }
});

/** Cron diario 02:30 America/Argentina/Buenos_Aires */
exports.scoringBatchDaily = onSchedule(
  {
    schedule: "30 2 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    const result = await runScoringBatch({ trigger: "scheduler" });
    console.log("scoringBatchDaily", result);
    return result;
  }
);
