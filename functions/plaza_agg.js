/**
 * Agregado puro del día de plaza. No lee Firestore y no copia PII.
 * El doc de salida solo tiene conteos, ids de oficio y nombres de zona.
 */
const UID_RE = /^[A-Za-z0-9]{20,36}$/;
const OFICIO_RE = /^[a-z0-9_]{1,48}$/;

const ROOT_KEYS = new Set([
  "ymd",
  "tz",
  "plaza",
  "cerrado",
  "schema",
  "altas",
  "altas_google",
  "altas_apple",
  "altas_email",
  "altas_otro",
  "clientes",
  "prestadores",
  "prestadores_completos",
  "invitados",
  "invitados_marca",
  "activos",
  "busquedas",
  "contactos",
  "contactos_origen",
  "contactos_tipo",
  "comprobantes_confirmados",
  "salto_dias",
  "salto_n",
  "salto_mediana",
  "oficios_buscados",
  "stock_completos_por_oficio",
  "stock_prestadores_completos",
  "zonas",
  "fuente",
]);

const ZONE_KEYS = new Set([
  "altas",
  "busquedas",
  "contactos",
  "prestadores_completos",
  "stock_completos",
  "oficios_buscados",
  "stock_completos_por_oficio",
  "salto_dias",
  "salto_n",
  "salto_mediana",
]);

function median(values) {
  const nums = (values || [])
    .map((n) => Number(n))
    .filter((n) => Number.isFinite(n))
    .sort((a, b) => a - b);
  if (!nums.length) return null;
  const mid = Math.floor(nums.length / 2);
  if (nums.length % 2) return nums[mid];
  return Math.round((nums[mid - 1] + nums[mid]) / 2);
}

function assertNumMap(map, path) {
  if (!map || typeof map !== "object" || Array.isArray(map)) {
    throw new Error("bad_map " + path);
  }
  for (const [k, v] of Object.entries(map)) {
    if (!OFICIO_RE.test(k) || typeof v !== "number") {
      throw new Error("bad_oficio " + path + k);
    }
  }
}

function assertSaltos(list, path) {
  if (!Array.isArray(list)) throw new Error("bad_saltos " + path);
  for (const n of list) {
    if (typeof n !== "number" || !Number.isFinite(n)) {
      throw new Error("bad_salto " + path);
    }
  }
}

function assertShape(doc) {
  for (const k of Object.keys(doc)) {
    if (!ROOT_KEYS.has(k)) throw new Error("pii_key " + k);
  }
  const origen = doc.contactos_origen || {};
  for (const k of Object.keys(origen)) {
    if (k !== "buscador" && k !== "tarjeta") throw new Error("pii_key origen_" + k);
  }
  const tipo = doc.contactos_tipo || {};
  for (const k of Object.keys(tipo)) {
    if (k !== "whatsapp" && k !== "llamada") throw new Error("pii_key tipo_" + k);
  }
  assertNumMap(doc.oficios_buscados, "oficios.");
  assertNumMap(doc.stock_completos_por_oficio, "stock.");
  assertSaltos(doc.salto_dias, "salto.");
  const zonas = doc.zonas || {};
  for (const [name, z] of Object.entries(zonas)) {
    if (name.includes("@") || /\d{6,}/.test(name)) throw new Error("pii_zona");
    for (const k of Object.keys(z)) {
      if (!ZONE_KEYS.has(k)) throw new Error("pii_key zona_" + k);
    }
    assertNumMap(z.oficios_buscados, "z.oficios.");
    assertNumMap(z.stock_completos_por_oficio, "z.stock.");
    assertSaltos(z.salto_dias, "z.salto.");
  }
}

function cleanLabel(raw) {
  const t = String(raw || "")
    .trim()
    .replace(/\s+/g, " ")
    .slice(0, 40);
  if (!t || t.includes("@") || /\d{6,}/.test(t)) return "";
  return t;
}

function canonZona(label) {
  const t = cleanLabel(label);
  if (!t) return "";
  if (t.toLowerCase().includes("pilar")) return "Pilar";
  return t;
}

function zonaDesdeUsuario(data) {
  const geo =
    data && data.direccion_geo && typeof data.direccion_geo === "object"
      ? data.direccion_geo
      : {};
  const cob =
    data && data.zonas_cobertura && typeof data.zonas_cobertura === "object"
      ? data.zonas_cobertura
      : {};
  let fromCob = "";
  const locs = Array.isArray(cob.localidades) ? cob.localidades : [];
  for (const l of locs) {
    if (l && typeof l === "object") {
      fromCob = l.nombre || l.localidad_nombre || "";
      if (String(fromCob).trim()) break;
    }
  }
  if (!fromCob && Array.isArray(cob.partidos)) {
    for (const p of cob.partidos) {
      if (p && typeof p === "object" && p.nombre) {
        fromCob = p.nombre;
        break;
      }
    }
  }
  return canonZona(geo.localidad_nombre || geo.partido_nombre || fromCob || "");
}

function tieneTelefono(data) {
  if (!data) return false;
  if (data.tiene_telefono === true || data.tiene_whatsapp === true) return true;
  return String(data.telefono || data.celular || "").trim().length > 0;
}

function oficiosDe(data) {
  const raw = [];
  if (data && Array.isArray(data.profesiones)) raw.push(...data.profesiones);
  if (data && Array.isArray(data.categorias_servicio)) {
    raw.push(...data.categorias_servicio);
  }
  const out = [];
  const seen = new Set();
  for (const item of raw) {
    const id = String(item || "")
      .trim()
      .toLowerCase();
    if (!OFICIO_RE.test(id) || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

function esPrestador(data) {
  if (!data) return false;
  if (data.es_trabajador === true) return true;
  const rol = String(data.rol || "").toLowerCase();
  if (rol === "trabajador" || rol === "prestador") return true;
  const camino = String(data.camino_elegido || "").toLowerCase();
  if (camino === "ofrezo" || camino === "ofrezco") return true;
  return oficiosDe(data).length > 0;
}

function esCompleto(data) {
  return (
    esPrestador(data) &&
    oficiosDe(data).length > 0 &&
    !!zonaDesdeUsuario(data) &&
    tieneTelefono(data)
  );
}

function authBucket(provider) {
  const s = String(provider || "").toLowerCase();
  if (s.includes("google")) return "google";
  if (s.includes("apple")) return "apple";
  if (
    s === "password" ||
    s.includes("email") ||
    s === "prox" ||
    s.includes("password")
  ) {
    return "email";
  }
  return "otro";
}

function emptyZona() {
  return {
    altas: 0,
    busquedas: 0,
    contactos: 0,
    prestadores_completos: 0,
    stock_completos: 0,
    oficios_buscados: {},
    stock_completos_por_oficio: {},
    salto_dias: [],
    salto_n: 0,
    salto_mediana: null,
  };
}

function touchZona(map, name) {
  if (!name) return null;
  if (!map[name]) map[name] = emptyZona();
  return map[name];
}

function uidDeDemanda(id) {
  const head = String(id || "").split("_")[0];
  return UID_RE.test(head) ? head : "";
}

function esMarcaInvitado(ev) {
  if (!ev) return false;
  const role = String(ev.role || "").toLowerCase();
  const name = String(ev.name || "").toLowerCase();
  if (role === "invitado" || role === "guest") return true;
  if (name.includes("invitado")) return true;
  return ev.guest === true && String(ev.type || "") === "session_start";
}

function inc(map, key) {
  map[key] = (map[key] || 0) + 1;
}

function buildPlazaDoc(input) {
  const users = input.users || [];
  const byId = new Map(users.map((u) => [u.id, u]));
  const zonas = {};
  const oficiosBuscados = {};
  const stockOficio = {};
  const stockByZona = {};
  let stockCompletos = 0;

  for (const u of users) {
    if (!esCompleto(u.data)) continue;
    stockCompletos += 1;
    const z = zonaDesdeUsuario(u.data);
    const ofs = oficiosDe(u.data);
    for (const id of ofs) inc(stockOficio, id);
    if (!z) continue;
    if (!stockByZona[z]) stockByZona[z] = { total: 0, porOficio: {} };
    stockByZona[z].total += 1;
    for (const id of ofs) inc(stockByZona[z].porOficio, id);
  }

  const doc = {
    ymd: String(input.ymd || ""),
    tz: "America/Argentina/Buenos_Aires",
    plaza: "Pilar",
    cerrado: true,
    schema: "plaza_v1",
    altas: 0,
    altas_google: 0,
    altas_apple: 0,
    altas_email: 0,
    altas_otro: 0,
    clientes: 0,
    prestadores: 0,
    prestadores_completos: 0,
    invitados: 0,
    invitados_marca: false,
    activos: 0,
    busquedas: 0,
    contactos: 0,
    contactos_origen: { buscador: 0, tarjeta: 0 },
    contactos_tipo: { whatsapp: 0, llamada: 0 },
    comprobantes_confirmados: Math.max(0, Number(input.comprobantes) || 0),
    salto_dias: [],
    salto_n: 0,
    salto_mediana: null,
    oficios_buscados: oficiosBuscados,
    stock_completos_por_oficio: stockOficio,
    stock_prestadores_completos: stockCompletos,
    zonas,
    fuente: "batch_0230",
  };

  const activos = new Set();

  function zoneDe(uid) {
    const u = byId.get(uid);
    return u ? zonaDesdeUsuario(u.data) : "";
  }

  for (const u of users) {
    if (
      u.creadoMs == null ||
      u.creadoMs < input.startMs ||
      u.creadoMs >= input.endMs
    ) {
      continue;
    }
    doc.altas += 1;
    const bucket = authBucket(u.data && u.data.auth_provider);
    doc["altas_" + bucket] += 1;
    const prestador = esPrestador(u.data);
    if (prestador) doc.prestadores += 1;
    else doc.clientes += 1;
    const completo = esCompleto(u.data);
    if (completo) doc.prestadores_completos += 1;
    const z = touchZona(zonas, zonaDesdeUsuario(u.data));
    if (z) {
      z.altas += 1;
      if (completo) z.prestadores_completos += 1;
    }
    const inv =
      u.data && typeof u.data.invitado_por === "string"
        ? u.data.invitado_por
        : "";
    if (!UID_RE.test(inv) || inv === u.id) continue;
    const parent = byId.get(inv);
    if (!parent || parent.creadoMs == null) continue;
    const days = Math.round((u.creadoMs - parent.creadoMs) / 86400000);
    if (!Number.isFinite(days) || days < 0 || days > 3650) continue;
    doc.salto_dias.push(days);
    if (z) z.salto_dias.push(days);
  }

  for (const ev of input.demanda || []) {
    doc.busquedas += 1;
    const oficio = String(ev.oficio_id || "")
      .trim()
      .toLowerCase();
    if (OFICIO_RE.test(oficio)) inc(oficiosBuscados, oficio);
    const uid = uidDeDemanda(ev.id);
    if (uid) activos.add(uid);
    const z = touchZona(zonas, zoneDe(uid));
    if (z) {
      z.busquedas += 1;
      if (OFICIO_RE.test(oficio)) inc(z.oficios_buscados, oficio);
    }
  }

  for (const c of input.contactos || []) {
    doc.contactos += 1;
    const origen = String(c.origen || "");
    const tipo = String(c.tipo || "");
    if (origen === "buscador" || origen === "tarjeta") {
      doc.contactos_origen[origen] += 1;
    }
    if (tipo === "whatsapp" || tipo === "llamada") {
      doc.contactos_tipo[tipo] += 1;
    }
    const uid = UID_RE.test(c.cliente_uid) ? c.cliente_uid : "";
    if (uid) activos.add(uid);
    const z = touchZona(zonas, zoneDe(uid));
    if (z) z.contactos += 1;
  }

  const sesiones = new Set();
  for (const ev of input.analytics || []) {
    const uid = UID_RE.test(ev.uid) ? ev.uid : "";
    if (uid) activos.add(uid);
    if (!esMarcaInvitado(ev)) continue;
    doc.invitados_marca = true;
    const sid = String(ev.session_id || ev.id || sesiones.size);
    if (!sesiones.has(sid)) {
      sesiones.add(sid);
      doc.invitados += 1;
    }
  }

  doc.activos = activos.size;
  doc.salto_n = doc.salto_dias.length;
  doc.salto_mediana = median(doc.salto_dias);

  for (const [name, z] of Object.entries(zonas)) {
    if (z.altas === 0 && z.busquedas === 0) {
      delete zonas[name];
      continue;
    }
    const st = stockByZona[name] || { total: 0, porOficio: {} };
    z.stock_completos = st.total;
    z.stock_completos_por_oficio = st.porOficio;
    z.salto_n = z.salto_dias.length;
    z.salto_mediana = median(z.salto_dias);
    if (z.salto_dias.length > 200) z.salto_dias = z.salto_dias.slice(0, 200);
  }
  if (doc.salto_dias.length > 200) doc.salto_dias = doc.salto_dias.slice(0, 200);

  assertShape(doc);
  return doc;
}

module.exports = {
  UID_RE,
  median,
  canonZona,
  zonaDesdeUsuario,
  esCompleto,
  authBucket,
  buildPlazaDoc,
  assertShape,
};
