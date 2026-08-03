const fs = require("fs");
const { GoogleAuth } = require("google-auth-library");

const PROJECT = process.env.GCLOUD_PROJECT || "lifewalletpuelo";
const RULES_PATH = process.env.RULES_PATH || "firestore.rules";

async function main() {
  const content = fs.readFileSync(RULES_PATH, "utf8");
  const auth = new GoogleAuth({
    scopes: [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/firebase",
    ],
  });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  if (!token) throw new Error("No access token");

  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };

  const createRes = await fetch(
    `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/rulesets`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({
        source: { files: [{ name: "firestore.rules", content }] },
      }),
    }
  );
  const createJson = await createRes.json();
  if (!createRes.ok) {
    console.error("Create ruleset failed", createRes.status, JSON.stringify(createJson));
    process.exit(1);
  }
  const rulesetName = createJson.name;
  console.log("Created ruleset:", rulesetName);

  // List releases
  const listRes = await fetch(
    `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
    { headers }
  );
  const listJson = await listRes.json();
  console.log("Existing releases:", JSON.stringify(listJson, null, 2));

  const releaseId = "cloud.firestore";
  const releaseResource = `projects/${PROJECT}/releases/${releaseId}`;

  // PATCH with only rulesetName
  let relRes = await fetch(
    `https://firebaserules.googleapis.com/v1/${releaseResource}?updateMask=rulesetName`,
    {
      method: "PATCH",
      headers,
      body: JSON.stringify({ rulesetName }),
    }
  );
  let relJson = await relRes.json();
  console.log("PATCH status", relRes.status, JSON.stringify(relJson));

  if (!relRes.ok) {
    // Try PUT style full replace via releases: update with name
    relRes = await fetch(
      `https://firebaserules.googleapis.com/v1/${releaseResource}?updateMask=rulesetName`,
      {
        method: "PATCH",
        headers,
        body: JSON.stringify({ name: releaseResource, rulesetName }),
      }
    );
    relJson = await relRes.json();
    console.log("PATCH2 status", relRes.status, JSON.stringify(relJson));
  }

  if (!relRes.ok) {
    process.exit(1);
  }
  console.log(JSON.stringify({ ok: true, rulesetName }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
