const fs = require("fs");
const { GoogleAuth } = require("google-auth-library");
const PROJECT = process.env.GCLOUD_PROJECT || "lifewalletpuelo";

async function main() {
  const content = fs.readFileSync("firestore.rules", "utf8");
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/firebase"],
  });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };

  // Create ruleset
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

  // GET existing release
  const relName = `projects/${PROJECT}/releases/cloud.firestore`;
  const getRes = await fetch(
    `https://firebaserules.googleapis.com/v1/${relName}`,
    { headers }
  );
  const getJson = await getRes.json();
  console.log("GET release", getRes.status, JSON.stringify(getJson, null, 2));

  // Try updateRelease with x-goog-request-params
  const bodies = [
    JSON.stringify({ rulesetName }),
    JSON.stringify({ name: relName, rulesetName }),
  ];
  for (const body of bodies) {
    for (const mask of ["rulesetName", "rulesetName,name"]) {
      const url = `https://firebaserules.googleapis.com/v1/${relName}?updateMask=${mask}`;
      const res = await fetch(url, { method: "PATCH", headers, body });
      const text = await res.text();
      console.log("PATCH", mask, res.status, text.slice(0, 250));
      if (res.ok) {
        console.log(JSON.stringify({ ok: true, rulesetName }));
        return;
      }
    }
  }

  // Try Firebase CLI style via firestore admin REST (rules not here)

  // Last: use googleapis firebaserules.projects.releases.update
  // Try with alt=json and $.xgafv
  const url2 = `https://firebaserules.googleapis.com/v1/${relName}?updateMask=rulesetName&alt=json`;
  const res2 = await fetch(url2, {
    method: "PATCH",
    headers: { ...headers, "X-Goog-User-Project": PROJECT },
    body: JSON.stringify({ rulesetName }),
  });
  console.log("PATCH x-user-project", res2.status, (await res2.text()).slice(0, 300));

  // Try POST to :update
  const res3 = await fetch(
    `https://firebaserules.googleapis.com/v1/${relName}:patch?updateMask=rulesetName`,
    { method: "POST", headers, body: JSON.stringify({ rulesetName }) }
  );
  console.log("POST :patch", res3.status, (await res3.text()).slice(0, 300));

  process.exit(1);
}
main().catch((e) => {
  console.error(e);
  process.exit(1);
});
