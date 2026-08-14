# Mis números — DB única (lifewalletpuelo)

Desde 2026-08-14 **no** usa el proyecto puelo-finanzas ni el bridge `exchangeWalletToken`.

- Auth: Firebase Auth de PROX (Google)
- Firestore: `usuarios/{uid}/movimientos|vault|metas|vencimientos` en **lifewalletpuelo**
- CF recovery: `registerVaultRecovery` / `recoverVaultDek` en región **us-east1**

Mensaje de producto:

> Tu PIN bloquea Mis números en el celular.
> Si lo olvidás, entrás de nuevo con Google y elegís uno nuevo.

Los datos que hubieran estado solo en puelo-finanzas **no se migran**.
