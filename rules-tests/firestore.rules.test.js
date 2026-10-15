/**
 * Qué hace: prueba firestore.rules contra el emulador, antes de publicarlas.
 *
 * Cubre el contrato que no se puede romper:
 * - un prestador se lee sin sesión (App Store 5.1.1);
 * - el preview de crédito y el readiness no se pueden escribir en el perfil;
 * - scoring_features y privado/identidad no los lee el directorio;
 * - badge y scoring público los escribe un admin, no el dueño.
 *
 * No es una Cloud Function ni entra al bundle. Lo corre CI.
 */
"use strict";

const { readFileSync } = require("fs");
const path = require("path");
const { describe, before, after, beforeEach, test } = require("node:test");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteField,
  collection,
  query,
  where,
  limit,
  getDocs,
} = require("firebase/firestore");

const PRESTADOR = "prestadoruidprestadoruid1";
const CLIENTE = "clienteuidclienteuidcliente1";
const OTRO = "otrouidotrouidotrouidotro1";

describe("firestore.rules", () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: "demo-puelo",
      firestore: {
        rules: readFileSync(path.join(__dirname, "../firestore.rules"), "utf8"),
        host: "127.0.0.1",
        port: 8080,
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "usuarios", PRESTADOR), {
        es_trabajador: true,
        nombre: "Ana",
        apellido: "Paz",
        badge_prestador: "bronce",
        scoring: { score_identidad: 40, score_servicio: 0 },
      });
      await setDoc(doc(db, "usuarios", CLIENTE), {
        es_trabajador: false,
        nombre: "Luis",
      });
      await setDoc(doc(db, "usuarios", PRESTADOR, "privado", "identidad"), {
        doc_numero: "000",
      });
      await setDoc(doc(db, "scoring_features", PRESTADOR), {
        readiness_microcredito: 10,
        interno: { score_credito_preview: 14 },
      });
      await setDoc(doc(db, "cat_oficios", "pintura"), { label: "Pintura" });
    });
  });

  test("sin sesión se lee un prestador activo", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "usuarios", PRESTADOR)));
  });

  test("sin sesión no se lee un cliente", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "usuarios", CLIENTE)));
  });

  test("sin sesión no se lista usuarios sin filtrar prestadores", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDocs(query(collection(db, "usuarios"), limit(20))));
  });

  test("sin sesión se lista solo prestadores", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, "usuarios"),
          where("es_trabajador", "==", true),
          limit(20)
        )
      )
    );
  });

  test("prestador dado de baja no se lee sin sesión", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "usuarios", PRESTADOR), {
        cuenta_eliminada: true,
      });
    });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "usuarios", PRESTADOR)));
  });

  test("sin sesión no lee scoring_features ni la identidad privada", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "scoring_features", PRESTADOR)));
    await assertFails(getDoc(doc(db, "usuarios", PRESTADOR, "privado", "identidad")));
  });

  test("otro usuario no lee privado ni scoring_features", async () => {
    const db = testEnv.authenticatedContext(OTRO).firestore();
    await assertFails(getDoc(doc(db, "usuarios", PRESTADOR, "privado", "identidad")));
    await assertFails(getDoc(doc(db, "scoring_features", PRESTADOR)));
  });

  test("el dueño lee su identidad privada", async () => {
    const db = testEnv.authenticatedContext(PRESTADOR).firestore();
    await assertSucceeds(getDoc(doc(db, "usuarios", PRESTADOR, "privado", "identidad")));
  });

  test("un admin lee scoring_features", async () => {
    const db = testEnv.authenticatedContext(OTRO, { admin: true }).firestore();
    await assertSucceeds(getDoc(doc(db, "scoring_features", PRESTADOR)));
  });

  test("el dueño actualiza su nombre y no el badge", async () => {
    const db = testEnv.authenticatedContext(PRESTADOR).firestore();
    await assertSucceeds(updateDoc(doc(db, "usuarios", PRESTADOR), { nombre: "Ana María" }));
    await assertFails(updateDoc(doc(db, "usuarios", PRESTADOR), { badge_prestador: "oro" }));
  });

  test("el dueño no escribe readiness ni el preview en su perfil", async () => {
    const db = testEnv.authenticatedContext(PRESTADOR).firestore();
    await assertFails(
      updateDoc(doc(db, "usuarios", PRESTADOR), { readiness_microcredito: 99 })
    );
    await assertFails(
      updateDoc(doc(db, "usuarios", PRESTADOR), {
        scoring: { score_identidad: 40, score_credito_preview: 80 },
      })
    );
  });

  test("un admin tampoco puede guardar el preview en el perfil público", async () => {
    const db = testEnv.authenticatedContext(OTRO, { admin: true }).firestore();
    await assertFails(
      updateDoc(doc(db, "usuarios", PRESTADOR), { score_credito_preview: 80 })
    );
    await assertFails(
      updateDoc(doc(db, "usuarios", PRESTADOR), {
        scoring: { score_identidad: 40, score_credito_preview: 80 },
      })
    );
  });

  test("un admin sí actualiza badge y scoring público, sin preview", async () => {
    const db = testEnv.authenticatedContext(OTRO, { admin: true }).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "usuarios", PRESTADOR), {
        badge_prestador: "bronce_plus",
        scoring: { score_identidad: 55, score_servicio: 0 },
      })
    );
  });

  test("si el perfil todavía tiene readiness viejo, el dueño puede cambiar el nombre", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "usuarios", PRESTADOR), {
        readiness_microcredito: 12,
      });
    });
    const db = testEnv.authenticatedContext(PRESTADOR).firestore();
    await assertSucceeds(updateDoc(doc(db, "usuarios", PRESTADOR), { nombre: "Ana" }));
  });

  test("un admin puede borrar el readiness viejo del perfil", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "usuarios", PRESTADOR), {
        readiness_microcredito: 12,
      });
    });
    const db = testEnv.authenticatedContext(OTRO, { admin: true }).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "usuarios", PRESTADOR), {
        readiness_microcredito: deleteField(),
      })
    );
  });

  test("catálogo se lee sin sesión y no se escribe", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "cat_oficios", "pintura")));
    await assertFails(setDoc(doc(db, "cat_oficios", "otro"), { label: "Otro" }));
  });

  test("una colección desconocida queda cerrada", async () => {
    const db = testEnv.authenticatedContext(OTRO, { admin: true }).firestore();
    await assertFails(getDoc(doc(db, "secreto", "x")));
  });
});
