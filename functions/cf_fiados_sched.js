const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { applyCors, requireBatchSecret } = require("./cf_shared");
const { runFiadosVtoBatch } = require("./fiados_vto");

exports.fiadosVtoDaily = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const result = await runFiadosVtoBatch({ force: false });
    console.log("fiadosVtoDaily", result);
    return result;
  }
);

exports.fiadosVtoEvening = onSchedule(
  {
    schedule: "0 18 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const result = await runFiadosVtoBatch({ force: false });
    console.log("fiadosVtoEvening", result);
    return result;
  }
);

exports.fiadosVtoHttp = onRequest(
  {
    invoker: "public",
    secrets: ["BATCH_SECRET"],
    memory: "512MiB",
    timeoutSeconds: 300,
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
    try {
      const result = await runFiadosVtoBatch({ force });
      res.status(200).json(result);
    } catch (e) {
      console.error("fiadosVtoHttp", e);
      res.status(500).json({ error: String(e.message || e) });
    }
  }
);
