# Apagar puelo-finanzas

Tras migrar Mis números (movimientos + metas + vencimientos), Academia y Equípate a **puelo-infra / lifewalletpuelo**, el proyecto Firebase `puelo-finanzas` ya no es necesario para PROX.

## Checklist operativo

1. Confirmar en la app PROX:
   - Mis números (PIN, movimientos, botones Metas / Vencimientos)
   - Academia (cápsulas + botón Equípate)
   - Equípate (simulador / pedido prueba)
2. No hay datos a migrar (decisión explícita: scrap).
3. En Firebase Console → proyecto **puelo-finanzas**:
   - Functions: borrar o desactivar `exchangeWalletToken`, `registerVaultRecovery`, `recoverVaultDek` si existían solo ahí.
   - Hosting: deshabilitar o borrar sitio si había deploy.
   - Firestore: se puede dejar en solo lectura o borrar la base cuando estés seguro.
   - Authentication: usuarios de prueba de Finanzas no se usan en PROX.
4. Repo GitHub `gdemagistre-hub/puelo-finanzas`:
   - Archivar el repositorio (Settings → Archive) o dejarlo como referencia histórica.
5. Quitar secretos/CI locales que apunten a `puelo-finanzas`.

## Qué quedó en puelo-infra

- `usuarios/{uid}/movimientos|metas|vencimientos|vault` (rules owner)
- CFs vault recovery + mensajes en us-east1
- UI: Mis números, Academia, Equípate
