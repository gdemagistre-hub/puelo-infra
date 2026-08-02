/**
 * Escribe cat_oficios/maestro con catálogo v2 (categoría → especialidad).
 * Uso: node seed_oficios.js
 * Requiere GOOGLE_APPLICATION_CREDENTIALS o ADC.
 */
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

async function main() {
  const seedPath = path.join(__dirname, "..", "data", "cat_oficios_seed.json");
  const seed = JSON.parse(fs.readFileSync(seedPath, "utf8"));
  const payload = {
    ...seed,
    actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
    fuente: "seed_oficios_v2",
  };
  await db.collection("cat_oficios").doc("maestro").set(payload, { merge: true });
  console.log(
    JSON.stringify({
      ok: true,
      especialidades: (seed.maestro || []).length,
      categorias: (seed.categorias || []).length,
      doc: "cat_oficios/maestro",
    })
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
