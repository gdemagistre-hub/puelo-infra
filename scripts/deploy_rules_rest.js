/**
 * Deploy firestore.rules via Firebase Rules REST API (no firebase CLI).
 * Requires GOOGLE_APPLICATION_CREDENTIALS + GCLOUD_PROJECT=lifewalletpuelo
 */
const fs = require("fs");
const path = require("path");
const { GoogleAuth } = require("google-auth-library");

const PROJECT = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "lifewalletpuelo";
const RULES_PATH = path.join(__dirname, "..", "firestore.rules");

async function main() {
  const source = fs.readFileSync(RULES_PATH, "utf8");
  if (!source.includes("rules_version")) {
    throw new Error("firestore.rules inválido o vacío");
  }

  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/firebase"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token || !token.token) throw new Error("No access token from SA");

  const headers = {
    Authorization: `Bearer ${token.token}`,
    "Content-Type": "application/json",
  };

  const createUrl = `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/rulesets`;
  const createBody = {
    source: {
      files: [{ name: "firestore.rules", content: source }],
    },
  };
  const createRes = await fetch(createUrl, {
    method: "POST",
    headers,
    body: JSON.stringify(createBody),
  });
  const createJson = await createRes.json();
  if (!createRes.ok) {
    console.error(createJson);
    throw new Error(`create ruleset failed: ${createRes.status}`);
  }
  const rulesetName = createJson.name;
  console.log("ruleset", rulesetName);

  const releaseBody = {
    name: `projects/${PROJECT}/releases/cloud.firestore`,
    rulesetName,
  };
  const releaseRes = await fetch(
    `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases/cloud.firestore?updateMask=rulesetName`,
    {
      method: "PATCH",
      headers,
      body: JSON.stringify(releaseBody),
    }
  );
  const releaseJson = await releaseRes.json();
  if (!releaseRes.ok) {
    const createRel = await fetch(
      `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
      {
        method: "POST",
        headers,
        body: JSON.stringify(releaseBody),
      }
    );
    const createRelJson = await createRel.json();
    if (!createRel.ok) {
      console.error("PATCH", releaseJson);
      console.error("POST", createRelJson);
      throw new Error(`release failed: ${releaseRes.status} / ${createRel.status}`);
    }
    console.log("release created", createRelJson);
  } else {
    console.log("release updated", releaseJson);
  }

  console.log("OK firestore.rules deployed to", PROJECT);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
