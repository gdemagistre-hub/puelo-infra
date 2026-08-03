const fs = require("fs");
const { GoogleAuth } = require("google-auth-library");
const PROJECT = process.env.GCLOUD_PROJECT || "lifewalletpuelo";

async function main() {
  const content = fs.readFileSync("firestore.rules", "utf8");
  const auth = new GoogleAuth({
    scopes: [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/firebase",
    ],
  });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
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
    console.error("Create failed", createRes.status, JSON.stringify(createJson));
    process.exit(1);
  }
  const rulesetName = createJson.name;
  console.log("Created", rulesetName);

  const listRes = await fetch(
    `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
    { headers }
  );
  const listJson = await listRes.json();
  console.log("Releases raw:", JSON.stringify(listJson, null, 2));

  const releaseResource = `projects/${PROJECT}/releases/cloud.firestore`;

  // Try several body shapes (API quirks)
  const attempts = [
    { updateMask: "rulesetName", body: { rulesetName } },
    { updateMask: "ruleset_name", body: { ruleset_name: rulesetName } },
    { updateMask: "rulesetName", body: { name: releaseResource, rulesetName } },
    { updateMask: "*", body: { name: releaseResource, rulesetName } },
  ];

  for (const a of attempts) {
    const url = `https://firebaserules.googleapis.com/v1/${releaseResource}?updateMask=${encodeURIComponent(a.updateMask)}`;
    const res = await fetch(url, {
      method: "PATCH",
      headers,
      body: JSON.stringify(a.body),
    });
    const j = await res.json();
    console.log("Attempt", a.updateMask, res.status, JSON.stringify(j).slice(0, 300));
    if (res.ok) {
      console.log(JSON.stringify({ ok: true, rulesetName }));
      return;
    }
  }

  // Last resort: projects.releases.create with replace via delete+create not allowed
  // Try POST with full name
  const postRes = await fetch(
    `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({ name: releaseResource, rulesetName }),
    }
  );
  const postJ = await postRes.json();
  console.log("POST", postRes.status, JSON.stringify(postJ).slice(0, 400));
  if (!postRes.ok) process.exit(1);
  console.log(JSON.stringify({ ok: true, rulesetName }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
