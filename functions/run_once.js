/**
 * Ejecuta el batch una vez (CI / Cloud Shell / local).
 * Uso:
 *   GOOGLE_APPLICATION_CREDENTIALS=sa.json node run_once.js
 *   FORCE=1 node run_once.js
 *   TRIGGER=github_actions node run_once.js
 */
const { runScoringBatch } = require("./scoringCore");

async function main() {
  const force = process.env.FORCE === "1" || process.env.FORCE === "true";
  const trigger = process.env.TRIGGER || "github_actions";
  console.log(JSON.stringify({ event: "batch_start", trigger, force }));
  const result = await runScoringBatch({ trigger, force });
  console.log(JSON.stringify({ event: "batch_done", ...result }, null, 2));
  if (result.status === "error" || result.status === "aborted_lock") {
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
