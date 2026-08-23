#!/usr/bin/env python3
from pathlib import Path


def patch_homepage():
    p = Path("lib/Homepage.dart")
    t = p.read_text()
    if "DemandaOficiosService" in t:
        print("Homepage already top-oficios")
        return
    old_imp = "import 'catalogo_oficios.dart';"
    new_imp = old_imp + "\nimport 'demanda/demanda_oficios_service.dart';"
    if old_imp not in t:
        raise SystemExit("hp import missing")
    t = t.replace(old_imp, new_imp, 1)

    t = t.replace(
        "static const List<Map<String, dynamic>> _categorias = [",
        "static const List<Map<String, dynamic>> _categoriasDefault = [",
        1,
    )
    needle = """    {'id': 'limpieza', 'label': 'Limpieza', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF8B5CF6)},
  ];
"""
    repl = """    {'id': 'limpieza', 'label': 'Limpieza', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF8B5CF6)},
  ];

  List<Map<String, dynamic>> _categorias =
      List<Map<String, dynamic>>.from(_categoriasDefault);
"""
    if needle not in t:
        raise SystemExit("hp categorias close missing")
    t = t.replace(needle, repl, 1)

    old_fcm = "    FcmService.instance.ensureStarted();"
    new_fcm = """    FcmService.instance.ensureStarted();
    _cargarTopOficios();"""
    if old_fcm not in t:
        raise SystemExit("hp fcm missing")
    t = t.replace(old_fcm, new_fcm, 1)

    old_ab = """  void _abrirBuscador({String? oficio}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BuscadorPrestadoresWidget(initialQuery: oficio)));
  }
"""
    new_ab = """  void _abrirBuscador({String? oficio}) {
    DemandaOficiosService.registrar(oficio, fuente: 'home');
    Navigator.push(context, MaterialPageRoute(builder: (_) => BuscadorPrestadoresWidget(initialQuery: oficio)));
  }

  Future<void> _cargarTopOficios() async {
    final next = await DemandaOficiosService.iconosHome();
    if (!mounted || next.isEmpty) return;
    setState(() => _categorias = next);
  }
"""
    if old_ab not in t:
        raise SystemExit("hp abrir missing")
    t = t.replace(old_ab, new_ab, 1)

    if t.count("{") != t.count("}"):
        raise SystemExit(f"hp braces {t.count('{')} {t.count('}')}")
    p.write_text(t)
    print("Homepage patched")


def patch_buscador():
    p = Path("lib/buscadorPrestadores.dart")
    t = p.read_text()
    if "DemandaOficiosService" in t:
        print("buscador already top-oficios")
        return
    old_imp = "import 'catalogo_oficios.dart';"
    new_imp = old_imp + "\nimport 'demanda/demanda_oficios_service.dart';"
    if old_imp not in t:
        raise SystemExit("busc import missing")
    t = t.replace(old_imp, new_imp, 1)

    old = """  void _onRubroSelected(String rubro) {
    if (_selectedRubro == rubro) return;
    setState(() => _selectedRubro = rubro);
    _cargarPrestadores(reset: true);
  }
"""
    new = """  void _onRubroSelected(String rubro) {
    if (_selectedRubro == rubro) return;
    setState(() => _selectedRubro = rubro);
    DemandaOficiosService.registrar(rubro, fuente: 'buscador_chip');
    _cargarPrestadores(reset: true);
  }
"""
    if old not in t:
        raise SystemExit("busc rubro missing")
    t = t.replace(old, new, 1)
    if t.count("{") != t.count("}"):
        raise SystemExit(f"busc braces {t.count('{')} {t.count('}')}")
    p.write_text(t)
    print("buscador patched")


def patch_rules():
    p = Path("firestore.rules")
    t = p.read_text()
    if "demanda_eventos" in t:
        print("rules already top-oficios")
        return
    old = """    // stats: scoring_job lock/runs + agregados — solo admin
    match /stats/{doc} {
      allow read: if isAdmin();
      allow write: if isAdmin();
      match /{document=**} {
        allow read: if isAdmin();
        allow write: if isAdmin();
      }
    }
"""
    new = """    // stats: scoring_job admin; top_servicios lo lee el Home cliente
    match /stats/{doc} {
      allow read: if isAdmin() || doc == 'top_servicios';
      allow write: if isAdmin();
      match /{document=**} {
        allow read: if isAdmin();
        allow write: if isAdmin();
      }
    }

    match /demanda_eventos/{id} {
      allow create: if request.resource.data.keys().hasOnly(
          ['oficio_id', 'fuente', 'created_at'])
        && request.resource.data.oficio_id is string
        && request.resource.data.oficio_id.size() > 0
        && request.resource.data.oficio_id.size() < 48
        && request.resource.data.fuente is string
        && request.resource.data.fuente.size() < 32;
      allow read: if isAdmin();
      allow update, delete: if false;
    }
"""
    if old not in t:
        raise SystemExit("rules stats block missing")
    t = t.replace(old, new, 1)
    p.write_text(t)
    print("rules patched")


def patch_index_js():
    p = Path("functions/index.js")
    t = p.read_text()
    if "runTopServiciosAyer" in t:
        print("index.js already top-oficios")
        return
    old = 'const { runScoringBatch } = require("./scoringCore");'
    new = 'const { runScoringBatch, runTopServiciosAyer } = require("./scoringCore");'
    if old not in t:
        raise SystemExit("index require missing")
    t = t.replace(old, new, 1)
    old2 = """    const result = await runScoringBatch({ trigger: \"scheduler\" });
    console.log(\"scoringBatchDaily\", result);
    return result;"""
    new2 = """    let top = { status: \"skipped\" };
    try {
      top = await runTopServiciosAyer();
      console.log(\"topServiciosAyer\", top);
    } catch (e) {
      console.error(\"topServiciosAyer\", e);
    }
    const result = await runScoringBatch({ trigger: \"scheduler\" });
    console.log(\"scoringBatchDaily\", result);
    return { scoring: result, topServicios: top };"""
    if old2 not in t:
        raise SystemExit("index schedule body missing")
    t = t.replace(old2, new2, 1)
    p.write_text(t)
    print("index.js patched")


def patch_scoring_core():
    p = Path("functions/scoringCore.js")
    t = p.read_text()
    if "runTopServiciosAyer" in t:
        print("scoringCore already top-oficios")
        return
    old = "module.exports = { runScoringBatch, MODEL_VERSION };"
    addon = '''const DEFAULT_OFICIOS = [
  "electricidad",
  "plomeria",
  "gasista",
  "carpinteria",
  "pintura",
  "albanileria",
  "jardineria",
  "limpieza",
];

const OFICIO_LABEL = {
  electricidad: "Electricista",
  plomeria: "Plomer\u00eda",
  gasista: "Gasista",
  carpinteria: "Carpinter\u00eda",
  pintura: "Pintura",
  albanileria: "Construcci\u00f3n",
  jardineria: "Jardiner\u00eda",
  limpieza: "Limpieza",
};

function ymdArt(date) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Argentina/Buenos_Aires",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function startOfArtDay(ymd) {
  return new Date(`${ymd}T00:00:00-03:00`);
}

async function runTopServiciosAyer() {
  const today = ymdArt(new Date());
  const yesterday = ymdArt(new Date(Date.now() - 24 * 60 * 60 * 1000));
  const start = startOfArtDay(yesterday);
  const end = startOfArtDay(today);
  const counts = {};
  let scanned = 0;
  let last = null;
  while (true) {
    let q = db
      .collection("demanda_eventos")
      .where("created_at", ">=", start)
      .where("created_at", "<", end)
      .orderBy("created_at")
      .limit(500);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      scanned += 1;
      const id = String((doc.data() || {}).oficio_id || "")
        .trim()
        .toLowerCase();
      if (!id) continue;
      counts[id] = (counts[id] || 0) + 1;
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < 500) break;
  }

  const ranked = Object.keys(counts).sort((a, b) => counts[b] - counts[a]);
  const ids = [];
  for (const id of ranked) {
    if (!ids.includes(id)) ids.push(id);
    if (ids.length >= 8) break;
  }
  for (const id of DEFAULT_OFICIOS) {
    if (ids.length >= 8) break;
    if (!ids.includes(id)) ids.push(id);
  }

  const items = ids.slice(0, 8).map((id) => ({
    id,
    label: OFICIO_LABEL[id] || id.replace(/_/g, " "),
    n: counts[id] || 0,
  }));

  const payload = {
    fecha_fuente: yesterday,
    actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
    items,
    counts,
    eventos_ayer: scanned,
    fuente: scanned > 0 ? "demanda" : "fallback",
  };
  await db.collection("stats").doc("top_servicios").set(payload, { merge: true });
  return {
    status: "ok",
    fecha_fuente: yesterday,
    fuente: payload.fuente,
    eventos: scanned,
    items,
  };
}

module.exports = { runScoringBatch, runTopServiciosAyer, MODEL_VERSION };
'''
    if old not in t:
        raise SystemExit("scoringCore export missing")
    t = t.replace(old, addon, 1)
    p.write_text(t)
    print("scoringCore patched")


if __name__ == "__main__":
    patch_homepage()
    patch_buscador()
    patch_rules()
    patch_index_js()
    patch_scoring_core()
