const assert = require("assert");
const { buildPlazaDoc, median } = require("./plaza_agg");

const day = Date.parse("2026-10-08T12:00:00-03:00");
const inviter = "ABCDEFGHIJabcdefghij123456";
const invitee = "ZYXWVUTSRQzyxwvutsrq654321";
const otro = "QQQQQQQQQQqqqqqqqqqq123456";

const doc = buildPlazaDoc({
  ymd: "20261008",
  startMs: Date.parse("2026-10-08T00:00:00-03:00"),
  endMs: Date.parse("2026-10-09T00:00:00-03:00"),
  comprobantes: 2,
  users: [
    {
      id: inviter,
      creadoMs: day - 4 * 86400000,
      data: {
        email: "secreto@ejemplo.com",
        telefono: "1155551234",
        nombre: "No Va",
        auth_provider: "google",
        es_trabajador: true,
        profesiones: ["electricidad"],
        tiene_telefono: true,
        direccion_geo: { localidad_nombre: "Pilar", calle: "Falsa 123" },
      },
    },
    {
      id: invitee,
      creadoMs: day,
      data: {
        email: "otro@ejemplo.com",
        telefono: "1199990000",
        auth_provider: "password",
        es_trabajador: false,
        invitado_por: inviter,
        direccion_geo: { localidad_nombre: "Pilar" },
      },
    },
    {
      id: otro,
      creadoMs: day,
      data: {
        auth_provider: "apple.com",
        es_trabajador: true,
        profesiones: ["plomeria"],
        tiene_whatsapp: true,
        zonas_cobertura: { localidades: [{ nombre: "Tigre" }] },
      },
    },
  ],
  demanda: [
    { id: invitee + "_20261008_electricidad", oficio_id: "electricidad" },
    { id: otro + "_20261008_plomeria", oficio_id: "plomeria" },
  ],
  contactos: [
    {
      cliente_uid: invitee,
      prestador_uid: inviter,
      origen: "buscador",
      tipo: "whatsapp",
      cliente_nombre: "No copiar",
      telefono: "1155551234",
    },
  ],
  analytics: [
    { type: "session_start", role: "cliente", uid: invitee, session_id: "s1" },
    { type: "session_start", role: "invitado", session_id: "g1" },
  ],
});

assert.strictEqual(median([8, 1, 4]), 4);
assert.strictEqual(median([]), null);
assert.strictEqual(doc.altas, 2);
assert.strictEqual(doc.altas_email, 1);
assert.strictEqual(doc.altas_apple, 1);
assert.strictEqual(doc.clientes, 1);
assert.strictEqual(doc.prestadores, 1);
assert.strictEqual(doc.prestadores_completos, 1);
assert.strictEqual(doc.busquedas, 2);
assert.strictEqual(doc.contactos, 1);
assert.strictEqual(doc.contactos_origen.buscador, 1);
assert.strictEqual(doc.contactos_tipo.whatsapp, 1);
assert.strictEqual(doc.comprobantes_confirmados, 2);
assert.strictEqual(doc.invitados, 1);
assert.strictEqual(doc.invitados_marca, true);
assert.strictEqual(doc.salto_n, 1);
assert.strictEqual(doc.salto_mediana, 4);
assert.strictEqual(doc.stock_prestadores_completos, 2);
assert.ok(doc.zonas.Pilar);
assert.strictEqual(doc.zonas.Pilar.busquedas, 1);
assert.strictEqual(doc.zonas.Pilar.stock_completos, 1);
assert.strictEqual(doc.zonas.Pilar.stock_completos_por_oficio.electricidad, 1);
assert.ok(doc.zonas.Tigre);
assert.strictEqual(doc.zonas.Tigre.altas, 1);

const raw = JSON.stringify(doc);
for (const leak of [
  "secreto@ejemplo.com",
  "otro@ejemplo.com",
  "1155551234",
  "1199990000",
  "Falsa 123",
  "No copiar",
  "No Va",
]) {
  assert.ok(!raw.includes(leak), "filtró " + leak);
}
assert.ok(!raw.includes("invitado_por"));
assert.ok(!raw.includes(inviter));
assert.ok(!raw.includes(invitee));

console.log("plaza_agg.test ok");
