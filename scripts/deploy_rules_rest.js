/**
 * Deploy firestore.rules via Firebase Rules REST API.
 * Avoids firebase-tools serviceusage "ensure API enabled" check.
 */
const fs = require("fs");
const { GoogleAuth } = require("google-auth-library");

const PROJECT = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "lifewalletpuelo";
const RULES_PATH = process.env.RULES_PATH || "firestore.rules";

async function main() {
  const content = fs.readFileSync(RULES_PATH, "utf8");
  const auth = new GoogleAuth({
    scopes: [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/firebase",
      "https://www.googleapis.com/auth/firebase.readonly",
    ],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) throw new Error("No access token from SA");

  const headers = {
    Authorization: `Bearer ${token.token}`,
    "Content-Type": "application/json",
  };

  // 1) Create ruleset
  const createBody = {
    source: {
      files: [{ name: "firestore.rules", content }],
    },
  };
  const createRes = await fetch(
    `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/rulesets`,
    { method: "POST", headers, body: JSON.stringify(createBody) }
  );
  const createJson = await createRes.json();
  if (!createRes.ok) {
    console.error("Create ruleset failed", createRes.status, JSON.stringify(createJson, null, 2));
    process.exit(1);
  }
  const rulesetName = createJson.name; // projects/.../rulesets/uuid
  console.log("Created ruleset:", rulesetName);

  // 2) Release to cloud.firestore
  const releaseName = `projects/${PROJECT}/releases/cloud.firestore`;
  const releaseBody = {
    name: releaseName,
    rulesetName,
  };
  // Try PATCH first (update), then POST create
  let relRes = await fetch(
    `https://firebaserules.googleapis.com/v1/${releaseName}?updateMask=rulesetName`,
    { method: "PATCH", headers, body: JSON.stringify(releaseBody) }
  );
  let relJson = await relRes.json();
  if (!relRes.ok) {
    console.log("PATCH failed, trying POST...", relRes.status, JSON.stringify(relJson));
    relRes = await fetch(
      `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
      { method: "POST", headers, body: JSON.stringify(releaseBody) }
    );
    relJson = await relRes.json();
  }
  if (!relRes.ok) {
    console.error("Release failed", relRes.status, JSON.stringify(relJson, null, 2));
    process.exit(1);
  }
  console.log("Released:", JSON.stringify(relJson, null, 2));
  console.log(JSON.stringify({ ok: true, rulesetName, project: PROJECT }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
