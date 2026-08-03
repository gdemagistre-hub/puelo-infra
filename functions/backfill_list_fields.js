/**
 * Backfill campos de listado liviano en usuarios prestadores.
 * - categorias_servicio
 * - zona_ids
 * - list_* 
 */
const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Mapa especialidad -> categoría (alineado a catalogo_oficios.dart v2)
const ESP_TO_CAT = {
  plomeria: "plomeria_gas",
  gasista: "plomeria_gas",
  destapaciones: "plomeria_gas",
  calefones: "plomeria_gas",
  bombas_agua: "plomeria_gas",
  tanques_agua: "plomeria_gas",
  electricidad: "electricidad",
  portero_electrico: "electricidad",
  iluminacion: "electricidad",
  albanileria: "construccion",
  techista: "construccion",
  impermeabilizacion: "construccion",
  colocacion_pisos: "construccion",
  drywall: "construccion",
  aberturas_aluminio: "construccion",
  herreria: "construccion",
  vidrieria: "construccion",
  piletas_construccion: "construccion",
  pintura: "pintura_acabados",
  empapelado: "pintura_acabados",
  revestimientos: "pintura_acabados",
  carpinteria: "madera_muebles",
  muebles_medida: "madera_muebles",
  tapiceria: "madera_muebles",
  decks: "madera_muebles",
  jardineria: "jardin_exterior",
  poda: "jardin_exterior",
  paisajismo: "jardin_exterior",
  riego: "jardin_exterior",
  cercos: "jardin_exterior",
  piletas_mantenimiento: "jardin_exterior",
  limpieza: "limpieza",
  limpieza_postobra: "limpieza",
  limpieza_alfombras: "limpieza",
  fumigacion: "limpieza",
  vidrios: "limpieza",
  aire_acondicionado: "clima",
  calefaccion: "clima",
  ventilacion: "clima",
  cctv: "seguridad_tech",
  alarmas: "seguridad_tech",
  cerrajeria: "seguridad_tech",
  redes_wifi: "seguridad_tech",
  soporte_pc: "seguridad_tech",
  domotica: "seguridad_tech",
  mudanzas: "mudanzas",
  fletes: "mudanzas",
  retiro_escombros: "mudanzas",
  paseador_perros: "mascotas",
  peluqueria_canina: "mascotas",
  pet_sitting: "mascotas",
  persianas: "hogar_varios",
  toldos: "hogar_varios",
  portones_automaticos: "hogar_varios",
  electrodomesticos: "hogar_varios",
  costura: "hogar_varios",
  organizacion_hogar: "hogar_varios",
};

function catsFromProfesiones(profesiones) {
  const set = new Set();
  for (const p of profesiones || []) {
    const k = String(p).toLowerCase().trim();
    if (!k) continue;
    if (ESP_TO_CAT[k]) set.add(ESP_TO_CAT[k]);
    else set.add(k);
  }
  return [...set];
}

function zonaIds(cobertura) {
  if (!cobertura || typeof cobertura !== "object") return [];
  const out = new Set();
  const add = (v) => {
    const s = String(v || "").trim();
    if (s) out.add(s);
  };
  add(cobertura.provincia_id);
  for (const p of cobertura.partidos || []) {
    if (p && typeof p === "object") add(p.id);
  }
  for (const l of cobertura.localidades || []) {
    if (l && typeof l === "object") add(l.id);
  }
  return [...out];
}

async function main() {
  const snap = await db.collection("usuarios").get();
  let batch = db.batch();
  let n = 0;
  let updated = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    const profesiones = (d.profesiones || []).map(String).filter(Boolean);
    const esTrab =
      d.es_trabajador === true || d.rol === "trabajador" || profesiones.length > 0;
    if (!esTrab && profesiones.length === 0) continue;

    const cats = catsFromProfesiones(profesiones);
    const zids = zonaIds(d.zonas_cobertura);
    const nombre = String(d.nombre || "").trim();
    const apellido = String(d.apellido || "").trim();
    const comercial = String(d.nombre_comercial || "").trim();
    const listNombre =
      comercial || `${nombre} ${apellido}`.trim() || "Prestador";
    const tel = String(d.telefono || d.celular || "").trim();
    const visible = profesiones.length > 0 && zids.length > 0 && tel.length > 0;
    const scoring = d.scoring || {};

    batch.set(
      doc.ref,
      {
        categorias_servicio: cats,
        zona_ids: zids,
        list_nombre: listNombre,
        list_foto: String(d.url_foto_perfil || ""),
        list_badge: d.badge_prestador || null,
        list_promedio: d.promedioEstrellas ?? null,
        list_n_eval: d.cantidadEvaluadores ?? null,
        list_score_servicio: scoring.score_servicio ?? null,
        list_score_identidad: scoring.score_identidad ?? null,
        list_visible: visible,
        es_trabajador: esTrab || profesiones.length > 0,
        list_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    n++;
    updated++;
    if (n >= 400) {
      await batch.commit();
      batch = db.batch();
      n = 0;
    }
  }
  if (n > 0) await batch.commit();

  await db.collection("stats").doc("list_fields_backfill").set(
    {
      ultima_corrida: admin.firestore.FieldValue.serverTimestamp(),
      usuarios_actualizados: updated,
      status: "ok",
    },
    { merge: true }
  );

  console.log(JSON.stringify({ ok: true, usuarios_actualizados: updated }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
