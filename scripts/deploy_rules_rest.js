/**
 * Deploy firestore.rules via Firebase Rules REST API (no firebase CLI).
 * Requires GOOGLE_APPLICATION_CREDENTIALS + GCLOUD_PROJECT=lifewalletpuelo
 */
const fs = require("fs");
const path = require("path");
const { GoogleAuth } = require("google-auth-library");

const PROJECT =
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  "lifewalletpuelo";
const RULES_PATH = path.join(__dirname, "..", "firestore.rules");
const RELEASE_NAME = `projects/${PROJECT}/releases/cloud.firestore`;

async function main() {
  const source = fs.readFileSync(RULES_PATH, "utf8");
  if (!source.includes("rules_version")) {
    throw new Error("firestore.rules inválido o vacío");
  }

  const auth = new GoogleAuth({
    scopes: [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/firebase",
    ],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token || !token.token) throw new Error("No access token from SA");

  const headers = {
    Authorization: `Bearer ${token.token}`,
    "Content-Type": "application/json",
  };

  // 1) Create ruleset
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

  // 2) Point release cloud.firestore at the new ruleset
  // Body: solo rulesetName (updateMask). Evita payload con campos desconocidos.
  const patchUrl =
    `https://firebaserules.googleapis.com/v1/${RELEASE_NAME}` +
    `?updateMask=rulesetName`;
  const patchBody = { rulesetName };

  let releaseRes = await fetch(patchUrl, {
    method: "PATCH",
    headers,
    body: JSON.stringify(patchBody),
  });
  let releaseJson = await releaseRes.json();

  // Fallback: algunos entornos esperan el recurso Release completo
  if (!releaseRes.ok) {
    console.warn("PATCH (solo rulesetName) falló:", releaseRes.status, releaseJson);
    releaseRes = await fetch(patchUrl, {
      method: "PATCH",
      headers,
      body: JSON.stringify({
        name: RELEASE_NAME,
        rulesetName,
      }),
    });
    releaseJson = await releaseRes.json();
  }

  // Fallback: crear release si no existiera (raro en proyectos ya configurados)
  if (!releaseRes.ok && releaseRes.status === 404) {
    console.warn("Release no existe, creando…");
    const createRel = await fetch(
      `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          name: RELEASE_NAME,
          rulesetName,
        }),
      }
    );
    const createRelJson = await createRel.json();
    if (!createRel.ok) {
      console.error("POST release", createRelJson);
      throw new Error(`release create failed: ${createRel.status}`);
    }
    console.log("release created", createRelJson);
  } else if (!releaseRes.ok) {
    console.error("PATCH release", releaseJson);
    throw new Error(`release update failed: ${releaseRes.status}`);
  } else {
    console.log("release updated", releaseJson);
  }

  console.log("OK firestore.rules deployed to", PROJECT);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
