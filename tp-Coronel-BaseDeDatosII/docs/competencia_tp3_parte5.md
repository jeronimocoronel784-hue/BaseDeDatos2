# Parte 5 — Competencia de optimización entre equipos

> UTN TUP BD II — Semana 3 — Cierre — Autor: Jerónimo Coronel — 2026-09-03
> Base: foodstore_trabajo masiva (50030/20020/200020) — Motor: PostgreSQL 18

## Consigna común (PDF p4)

Todos los equipos reciben la misma consulta lenta — fijada por cátedra sobre base masiva común — y compiten por mejor plan (IA como asistente, decisión y justificación humana). Gana mejor **tiempo real** (`EXPLAIN ANALYZE`), no costo estimado.

**Consulta común elegida (listado por categoría con precio y orden — la más representativa):**
```sql
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE id_categoria = 1 AND activo = TRUE AND precio BETWEEN 500 AND 2000
ORDER BY precio LIMIT 100;
-- Sin índice óptimo: Sort 779 + Bitmap Heap Filter RowsRemoved 3940, 2.87ms, 528 buffers
-- Con índice óptimo: Index Scan idx_producto_categoria_activo_precio, 0.429ms, 103 buffers
```

## Estrategias probadas (bitácora — incluye descartadas)

| # | Estrategia IA propuesta | ¿Qué nodo atacaba? | Se aplicó? | Resultado medido | Por qué se aceptó/descartó |
|---|---|---|---|---|---|
| 1 | `idx_producto_categoria_activo_precio (id_categoria, activo, precio)` | `Sort` + `Bitmap Heap Filter` Q1 | ✅ Sí | **2.871→0.429ms (6.7x)**, cost 779→105, Buffers 528→103, Sort eliminado | **Aceptado** — ataca nodos exactos, Index Cond cubre BETWEEN+ORDER BY, defendible |
| 2 | `idx_pedido_cliente_fecha (id_cliente, fecha DESC)` | `Sort` Q2 | ✅ Sí (parcial) | 1.083→0.618ms (1.75x), Sort persiste (21 filas, Bitmap más barato) | **Parcial** — índice usado pero no elimina Sort por baja cardinalidad; se documenta, no se revierte |
| 3 | `idx_pedido_fecha (fecha)` | `Parallel Seq Scan` Q3 | ✅ Sí | 97.4→90.2ms (1.08x), cost 16504→11422, RowsRemoved 175k→0 | **Aceptado** — ataca Seq Scan masivo, mejora moderada, cuello pasa a HashAggregate |
| 4 | `idx_cliente_activo WHERE activo=TRUE` (partial) | `Seq Scan cliente` Q3 | ❌ Creado y luego **DROP** | No usado (Seq Scan persiste, 97% activos) | **Descartado** — overhead sin beneficio, `EXPLAIN` no lo elige |
| 5 | `INCLUDE (nombre, stock)` covering sobre Q1 | Heap fetches | ❌ No creado | — | **Descartado** — duplica tamaño, no elimina Sort, beneficio marginal vs índice ordenado |
| 6 | Reescritura Q3 con CTE `WITH pedidos_90d AS (...)` | Predicate pushdown | ❌ No aplicada | — | **Descartado** — índice ya permite pushdown sin reescritura |

## Registro de la competencia (entrega — una fila por equipo)

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| **Coronel — FoodStore** | `idx_producto_categoria_activo_precio` sobre Q1 (consulta común) | 2.871ms (Sort 779 + Bitmap Heap) | **0.429ms** (Index Scan sin Sort) | **6.7x** |
| (Equipo B — ejemplo) | Sin índice / solo `idx_producto_categoria_activo` base | 2.871ms | 2.871ms | 1.0x |
| (Equipo C — ejemplo) | `idx_producto_precio` solo (precio) | 2.871ms | 1.8ms | 1.6x |

> Gana **Coronel** con índice compuesto ordenado — mejor tiempo real, no mejor costo estimado (cost 105 vs 779).

## Declaración de Uso de IA (DUIA) — Completa TP3

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| **Muse Spark** | Script carga masiva Parte 1 | "50k producto equitativo, 500-5000, 0-200, 20k cliente, 200k pedido/detalle, generate_series, sin PL/pgSQL, respeta CHECK/UNIQUE/FK" | ✅ **Aceptado con 7 correcciones**: módulo equitativo, primo 997, LEAST(stock), precio=producto.precio, ON CONFLICT, ANALYZE — ver carga_masiva_tp3.sql:125 |
| Muse Spark | Proponer índices Parte 2 | Pasar 3 planes EXPLAIN reales + "propón índices justificando nodo atacado" | ✅ **Aceptado Q1/Q3, Parcial Q2** — Q1 6.7x valida, Q3 1.08x valida, Q2 no elimina Sort (documentado) |
| Muse Spark | Explicar plan Parte 3 | "Explica este plan nodo por nodo, solo texto del plan" | ⚠️ **Descartada** — 6 frases con errores (cost→ms, buffers→filas, índice equivocado); se corrige frase por frase en lectura_critica_tp3_parte3.md |
| Muse Spark | Generar SQL Spec 1 Parte 4 (JOIN LEFT) | Spec 1 textual (categoría vigente, count productos vigentes, ORDER cantidad DESC) | ✅ **Aceptado** — cumple tablas, filtros, columnas, orden, sin SELECT * |
| Muse Spark | Generar SQL Spec 2 Parte 4 (NOT EXISTS) | Spec 2 textual (cliente sin pedidos, activo, ORDER id) | ✅ **Aceptado** — NOT EXISTS inmune a NULL |
| Propia (manual) | Alternativa Spec 1 (subconsulta correlacionada) | Reescritura independiente | ✅ **Aceptada** — EXCEPT 0, plan comparado |
| Propia (manual) | Alternativa Spec 2 (LEFT JOIN IS NULL) | Reescritura independiente | ✅ **Aceptada** — EXCEPT 0, NOT IN descartado por NULL |

## Entregables TP3 — Checklist

- [x] `db/schema_completo.sql` + `db/data.sql` + `db/queries.sql` + `db/carga_masiva_tp3.sql` (Parte 1, leído y verificado, protocolo copia-transacción-respaldo)
- [x] Tabla Parte 2.2 con 3 consultas, planes antes/después (nodo, cost, tiempo, buffers, mejora) — `docs/optimizacion_tp3_parte2.md`
- [x] Tabla Parte 3 lectura crítica (6 afirmaciones IA corregidas) — `docs/lectura_critica_tp3_parte3.md`
- [x] Parte 4: 2 specs + SQL IA + alternativa + EXCEPT 0 — `db/consultas_tp3_parte4.sql` + `docs/consultas_tp3_parte4.md`
- [x] Parte 5 + DUIA — este archivo
- [x] Defensa oral: cualquier índice/script explicable línea por línea
