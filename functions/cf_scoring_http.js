const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { runScoringBatch, runTopServiciosAyer } = require("./scoringCore");
const {
  applyCors,
  requireBatchSecret,
} = require("./cf_shared");

exports.scoringBatchHttp = onRequest(
  {
    invoker: "public",
    secrets: ["BATCH_SECRET"],
  },
  async (req, res) => {
    applyCors(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }
    if (!requireBatchSecret(req, res)) return;
    const force = !!(req.body && req.body.force === true);
    const trigger = (req.body && req.body.trigger) || "http";
    try {
      const result = await runScoringBatch({ trigger, force });
      res.status(200).json(result);
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);

exports.scoringBatchDaily = onSchedule(
  {
    schedule: "30 2 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    let top = { status: "skipped" };
    try {
      top = await runTopServiciosAyer();
      console.log("topServiciosAyer", top);
    } catch (e) {
      console.error("topServiciosAyer", e);
    }
    const result = await runScoringBatch({ trigger: "scheduler" });
    console.log("scoringBatchDaily", result);
    return { scoring: result, topServicios: top };
  }
);
