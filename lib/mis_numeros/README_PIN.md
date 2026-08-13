# Mis números — PIN y recuperación

Mensaje de producto:

> Tu PIN bloquea Mis números en el celular.
> Si lo olvidás, entrás de nuevo con Google y elegís uno nuevo.

## Modelo v2
- DEK aleatoria cifra montos/notas
- PIN envuelve la DEK (`dek_wrapped_pin`)
- CF `registerVaultRecovery` / `recoverVaultDek` permiten reset de PIN sin perder historial

## Legacy v1
- Clave = PIN derivado
- Sin `dek_wrapped_recovery` → "Olvidé el PIN" puede fallar; hay que recrear bóveda

## Deploy CF (puelo-finanzas)
```
firebase deploy --only functions:registerVaultRecovery,functions:recoverVaultDek,functions:exchangeWalletToken
```
