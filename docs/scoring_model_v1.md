# Puelo Scoring Model v1.0

**Estado:** productivo en batch (`ScoringService.modelVersion = v1.0`)  
**ML/IA:** fuera de alcance (etapa microcrédito)  
**UI:** badge + confianza de perfil + estrellas/evals; **no** mostrar `score_credito_preview`

## Capas

| Campo | Visible | Significado |
|-------|---------|-------------|
| `scoring.score_identidad` (0–100) | Sí (confianza) | ¿Es quien dice ser? |
| `scoring.score_servicio` (0–100) | Sí (orden / calidad) | Qué tan bueno es como prestador |
| `scoring.score_cliente` (0–100) | Sí (sello cliente) | Confiabilidad como cliente |
| `scoring.score_credito_preview` | No | Preview interno futuro crédito |
| `badge_prestador` | Sí | Escalera de hitos |
| `score_credito` (plano) | No (compat) | Raw legado / compat batch |

## Identidad (techo raw 50 → 0–100)

Señales principales: auth (Google 3), email (2), celular (1), OCR doc (8), foto doc (3), foto perfil (3), ancla doc (×2 si OCR), domicilio, oficios, zona, hasta 5 fotos propias.

## Servicio

Base por evento: identidad 3 / trabajo sin foto 2 / con foto 3 / foto+comentario 4.  
Multiplicador evaluador: nuevo 0.25 · id≤receptor 0.50 · id>receptor 0.70 · +historial 1.00 · solo-identidad 0.15.  
Par completo: ×1.10.

## Badge

nuevo → registrado → bronce → bronce_plus (OCR) → plata (≥10 evals/validadores con historial).

## Ops

- Cálculo: `ScoringService.ejecutarBatchDiario()` (Home dev o scheduler).
- No recalcular en cada save de pantalla.
- `stats/scoring_job` guarda `model_version`.


## Métricas de discriminación (etapa microcrédito) — DOCUMENTACIÓN CLAVE

**Alcance:** Gini, KS y ROC/AUC son el estándar de validación de **modelos de scoring de riesgo/crédito**.  
**Etapa actual (confianza / prestador / cliente):** no se reportan como KPI de producto porque el *target* no es default crediticio.  
**Etapa futura (microcrédito / PD):** **sí** se usarán para validar el modelo de probabilidad de default (y, si aplica, modelos de fraude con label binario).

### Definiciones

| Métrica | Fórmula / idea | Interpretación |
|---------|----------------|----------------|
| **ROC / AUC** | Curva TPR vs FPR al variar el umbral del score | Capacidad de **ordenar** buenos vs malos (0.5 = azar, 1 = perfecto) |
| **Gini** | \(Gini = 2 \times AUC - 1\) | Misma información que AUC; escala habitual en banca (0–1 o 0–100%) |
| **KS (Kolmogorov–Smirnov)** | Máxima distancia entre CDF de buenos y malos en el score | Punto de **máxima separación**; útil para cortes de política |

Complementarios (no son Gini/KS, pero van en el mismo model doc):

- **Calibración:** ¿un score 70 implica ~X% de default real?
- **Estabilidad (PSI):** deriva del score y de los inputs en el tiempo
- **Umbrales de política:** aprobar / revisar / rechazar usando ROC o KS

### Cuándo se pueden calcular de verdad

1. **Definición de evento** (ej. default a 30/60/90 días; o fraude sí/no).
2. **Score en un momento \(t\)** (snapshot del batch o del modelo de PD).
3. **Outcome observado en \(t+h\)** sobre el mismo universo.
4. Volumen suficiente de ambos lados (pocos defaults → Gini/KS inestables).

Sin (1)–(3) se documenta el **marco**, no un Gini inventado.

### Relación con las capas Puelo v1.0

| Capa / campo | ¿Gini-KS-ROC hoy? | Notas |
|--------------|-------------------|--------|
| `score_identidad` (confianza) | No como KPI crédito | Target = señales de identidad/comunidad; se puede definir labels operativos (fraude de validación, etc.) más adelante |
| `score_servicio` / evals | No | Calidad de servicio, no mora |
| `score_cliente` | No | Confiabilidad de cliente en la app |
| `score_credito_preview` | Reservado | Preview interno; **no UI**. En etapa microcrédito se reemplaza/alimenta con PD validado por AUC/Gini/KS |
| Batch fraude (`riesgo_fraude`) | Opcional futuro | Con label fraude/no fraude se pueden reportar AUC/Gini/KS del detector |

### Texto canónico para model doc / inversores / comité

> En la etapa de **confianza de perfil y reputación de servicio**, Puelo no reporta Gini, KS ni AUC porque el objetivo del score no es default crediticio.  
> En la etapa de **microcrédito**, el modelo de PD se validará con **AUC**, **Gini (= 2·AUC − 1)** y **KS** sobre muestra **out-of-time**, con definición de default a 30/60/90 días, más calibración y PSI.  
> Los scores de identidad/servicio/cliente de v1.0 son **features y controles de elegibilidad/anti-fraude**, no el score de crédito publicado al usuario en esta etapa.

### Checklist etapa 2 (cuando se active microcrédito)

- [ ] Definir default (días de atraso / write-off)
- [ ] Guardar snapshot de score (y features) en origen de solicitud
- [ ] Observar outcomes con horizonte fijo
- [ ] Reportar AUC, Gini, KS (desarrollo + out-of-time)
- [ ] Calibración y PSI en monitoreo
- [ ] Política de cortes documentada (no solo maximizar Gini)

**Decisión de producto (2026-08):** mantener Gini/KS/ROC como **requisito de documentación y validación de la etapa crédito**; no implementar su cálculo en el batch de confianza v1.0.

## Changelog

- **v1.0** — Capas A/B/C + preview crédito; foto perfil y OCR explícitos; multiplicadores de evaluador.
- **v1.0-doc** — Sección métricas discriminación (AUC/Gini/KS) para etapa microcrédito; no KPI de confianza actual.

## Batch

Ver [scoring_batch.md](./scoring_batch.md). Pipeline F0–F5 en `ScoringService.ejecutarBatchDiario` y Cloud Functions.
