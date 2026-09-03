# Parte 2 — Lectura crítica de nodos join — FoodStore (EJEMPLO SINTÉTICO VEROSÍMIL)

> UTN TUP BD II — Semana 4 — Parte 2 — Autor: Jerónimo Coronel — 2026-09-03 — **EJEMPLO SINTÉTICO**
> Base: `foodstore_trabajo` con índices Semana 3 (`idx_producto_categoria_activo_precio`, `idx_pedido_cliente_fecha`, `idx_pedido_fecha`) + índices Parte 1 (`idx_pedido_fecha_id`, `idx_producto_categoria_activo`, `idx_cliente_activo_true`) — PostgreSQL 16.8
> Motor: PostgreSQL 16 — `EXPLAIN (ANALYZE, BUFFERS)` — planes **sintéticos verosímiles** para practicar lectura crítica sin base real.

## Regla de oro (memorizar para defensa oral)

> **"costo estimado (`cost=..`) es planificación del optimizador, tiempo real (`actual time=..`) es ejecución medida — no confundir"**
>
> `cost=0.42..4890.25` son **unidades abstractas** (`seq_page_cost = 1.0`, `random_page_cost = 4.0`) que el planner usa para **elegir** plan. `actual time=0.028..44.218` es **medición real** con `clock_gettime()` por nodo (tiempo hasta primera fila .. hasta última fila, en **ms**). Gana quien tenga menor `actual time` / `Execution Time`, no menor `cost`. `Buffers: shared hit/read` son **páginas de 8KB**, no filas (`rows` son filas).

## Metodología

1. Tomar plan real de Parte 1 ya medido con `EXPLAIN (ANALYZE, BUFFERS)` — en este ejemplo, el **plan Q1 DESPUÉS** (con `idx_pedido_fecha_id` e `idx_producto_categoria_activo`, al menos 2 nodos de join).
2. Pedir a IA (OpenCode/Kiro) que explique el plan nodo por nodo sin más contexto que el texto del plan.
3. Contrastar frase por frase contra plan real, marcando errores de interpretación (cost→ms, externa/interna, Buffers→filas, etc.).
4. Documentar en tabla §3 con **evidencia textual exacta** del plan (líneas copiadas).

## Guía rápida para diferenciar nodos join

### Nested Loop — externa vs interna

```text
Nested Loop  (cost=1.42..4650.30 rows=48210 width=48) (actual time=0.085..28.445 rows=48210 loops=1)
  Buffers: shared hit=512 read=48
  ->  Index Scan using idx_pedido_fecha_id on pedido p  (cost=0.42..890.10 rows=48210 width=12) (actual time=0.028..4.102 rows=48210 loops=1)  -- EXTERNA
        Index Cond: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now()))
        Buffers: shared hit=210 read=15
  ->  Nested Loop  (cost=1.00..7.12 rows=1 width=36) (actual time=0.0004..0.0005 rows=1 loops=48210)  -- INTERNA (se ejecuta 48210 veces)
        Buffers: shared hit=302 read=33
        ->  Index Scan using idx_detalle_pedido_pkey on detalle_pedido dp  (cost=0.42..2.10 rows=1 width=16) (actual time=0.0002..0.0003 rows=1 loops=48210)
              Index Cond: (dp.id_pedido = p.id_pedido)   -- Index Cond usa outer.col
```

- **Externa (outer):** se recorre una vez (`loops=1`), suele ser la tabla filtrada o pequeña. Aparece como **primer hijo** del `Nested Loop`.
- **Interna (inner):** se ejecuta `N` veces (`loops=N`, `actual time` es **promedio por loop**, tiempo total = `actual time × loops`). Cada iteración hace `Index Cond: ... = outer.col`.
- **Pista IA errónea típica:** "Nested Loop es siempre malo" — falso; con `loops` bajo y `Index Scan` interno es óptimo (ej. Q1 DESPUÉS `loops=48210` pero `actual 0.0005ms/loop` → 24ms total). Con `loops` alto (100k) y `Seq Scan` interno es catastrófico.
- **Buffers:** externa `hit/read` una vez; interna `Buffers × loops` (multiplicar mentalmente para costo total I/O).

### Hash Join — build vs probe

```text
Hash Join  (Hash Cond: dp.id_pedido = p.id_pedido) (cost=4120.33..5890.12 rows=48210 width=28) (actual time=62.340..98.775 rows=48210 loops=1)
  Buffers: shared hit=3610 read=227
  ->  Seq Scan on pedido p  (cost=0.00..3890.00 rows=200020 width=12) (actual time=0.015..48.112 rows=200020 loops=1)  -- PROBE (grande, sondea)
  ->  Hash  (cost=2890.00..2890.00 rows=200020 width=16) (actual time=62.310..62.310 rows=200020 loops=1)  -- BUILD
        Buckets: 131072  Batches: 1  Memory Usage: 4096kB
        ->  Seq Scan on detalle_pedido dp  (cost=0.00..2890.00 rows=200020 width=16) (actual time=0.012..18.440 rows=200020 loops=1)  -- BUILD pequeña
```

- **Build (hash):** tabla pequeña que se carga en hash table (`Hash` hijo, `Batches`, `Memory`, `Buckets`). Ideal que entre en `work_mem` (`Batches 1`).
- **Probe (sondeo):** tabla grande que recorre y busca en el hash. Aparece como **primer hijo** del `Hash Join`.
- **Error típico IA:** confundir build con probe, o decir "Hash Join siempre necesita índice" — no, usa hash en memoria, no índice.
- **Señal de problema:** `Batches >1` o `Disk: ...kB` = spill a disco por `work_mem` insuficiente.

### Merge Join — orden requerido

```text
Merge Join  (Merge Cond: pr.id_categoria = c.id_categoria) (cost=1234.10..7890.45 rows=48210 width=48) (actual time=42.115..145.230 rows=48210 loops=1)
  ->  Sort  (cost=890.22..920.10 rows=45200 width=24) (actual time=18.210..22.445 rows=45200 loops=1)
        Sort Key: pr.id_categoria
        Sort Method: quicksort  Memory: 3201kB
```

- Requiere ambas entradas **ordenadas** por la clave de join. Si no hay índice ordenado, verás `Sort` explícito antes del `Merge Join`.
- Si ves `Merge Join` sin `Sort` previo, es porque hay índice `(id_categoria)` que ya entrega orden.

### Costo estimado vs tiempo real — checklist

| Concepto | Dónde verlo | Unidad | Uso |
|---|---|---|---|
| `cost=0.42..4890.25` | cada nodo | unidades `seq_page_cost` | Planner elige plan de menor cost — **no es ms** |
| `actual time=0.028..44.218` | cada nodo con `ANALYZE` | **ms** (hasta 1ra fila .. hasta última) | Tiempo real medido — **comparar para decidir ganador** |
| `Planning Time` | pie del plan | ms | Tiempo que tardó el optimizador en planificar |
| `Execution Time` | pie del plan | ms | Tiempo total ejecución — **criterio competencia** |
| `Buffers: shared hit/read` | cada nodo con `BUFFERS` | **páginas 8KB** | `hit` = cache, `read` = disco — no son filas |
| `rows` | cada nodo | filas | Cardinalidad estimada vs real (`rows=48210`) |
| `loops` | cada nodo | iteraciones | `loops=1` externa, `loops=N` interna — multiplicar `actual time × loops` para total |

---

## Plan real elegido (Q1 DESPUÉS — con al menos 2 nodos de join) — PEGADO COMPLETO

**Query elegida — Q1 Facturación por categoría y mes (Parte 1 Q1):**
```sql
SELECT
    c.nombre                             AS categoria,
    date_trunc('month', p.fecha)         AS mes,
    sum(dp.cantidad * dp.precio_unitario) AS facturacion,
    count(DISTINCT p.id_pedido)           AS pedidos
FROM categoria c
JOIN producto pr        ON pr.id_categoria = c.id_categoria
JOIN detalle_pedido dp  ON dp.id_producto = pr.id_producto
JOIN pedido p           ON p.id_pedido = dp.id_pedido
WHERE c.activo = TRUE
  AND pr.activo = TRUE
  AND p.fecha BETWEEN now() - interval '6 months' AND now()
GROUP BY c.nombre, mes
ORDER BY facturacion DESC
LIMIT 20;
```

**Plan real (`EXPLAIN (ANALYZE, BUFFERS)` en foodstore_trabajo — SINTÉTICO VEROSÍMIL, formato PostgreSQL 16):**
```text
Limit  (cost=4890.20..4890.25 rows=20 width=64) (actual time=44.210..44.218 rows=20 loops=1)
  Buffers: shared hit=512 read=48
  ->  Sort  (cost=4890.20..4890.75 rows=220 width=64) (actual time=44.208..44.212 rows=20 loops=1)
        Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
        Sort Method: top-N heapsort  Memory: 31kB
        Buffers: shared hit=512 read=48
        ->  HashAggregate  (cost=4878.10..4884.70 rows=220 width=64) (actual time=43.102..43.389 rows=198 loops=1)
              Group Key: c.nombre, (date_trunc('month'::text, p.fecha))
              Batches: 1  Memory Usage: 73kB
              Buffers: shared hit=512 read=48
              ->  Nested Loop  (cost=1.42..4650.30 rows=48210 width=48) (actual time=0.085..28.445 rows=48210 loops=1)
                    Buffers: shared hit=512 read=48
                    ->  Index Scan using idx_pedido_fecha_id on pedido p  (cost=0.42..890.10 rows=48210 width=12) (actual time=0.028..4.102 rows=48210 loops=1)
                          Index Cond: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now()))
                          Buffers: shared hit=210 read=15
                    ->  Nested Loop  (cost=1.00..7.12 rows=1 width=36) (actual time=0.0004..0.0005 rows=1 loops=48210)
                          Buffers: shared hit=302 read=33
                          ->  Index Scan using idx_detalle_pedido_pkey on detalle_pedido dp  (cost=0.42..2.10 rows=1 width=16) (actual time=0.0002..0.0003 rows=1 loops=48210)
                                Index Cond: (dp.id_pedido = p.id_pedido)
                                Buffers: shared hit=145 read=10
                          ->  Index Scan using idx_producto_categoria_activo on producto pr  (cost=0.28..4.45 rows=1 width=12) (actual time=0.0001..0.0002 rows=1 loops=48210)
                                Index Cond: ((pr.id_producto = dp.id_producto) AND (pr.activo = TRUE))
                                Buffers: shared hit=157 read=23
Planning Time: 2.105 ms
Execution Time: 45.820 ms
```

**Lectura correcta del plan (referencia para contrastar — evidencia textual):**
- `cost=4890.20..4890.25` significa: **costo estimado acumulado del planner** (unidades abstractas, `seq_page_cost=1.0`), no milisegundos; el Limit estima 20 filas.
- `actual time=44.210..44.218` significa: **tiempo real medido** del nodo Limit — 44.210ms hasta primera fila, 44.218ms hasta última (20 filas, `loops=1`).
- `Buffers: shared hit=512 read=48` significa: **512 páginas de 8KB** leídas de `shared_buffers` (cache) y 48 de disco; no son filas (`rows=20` son filas).
- Nodo join real: **Nested Loop** (externa `pedido p` vía `Index Scan using idx_pedido_fecha_id`, `loops=1`, 48 210 filas; interna `Nested Loop` con `detalle_pedido dp` + `producto pr` vía `Index Scan`, `loops=48210`, una por fila externa, `Index Cond: dp.id_pedido = p.id_pedido`). Tiempo total interna = `0.0005ms × 48210 ≈ 24.1ms` (no 0.0005ms).
- ¿Hay `Sort`? **Sí**, `Sort Method: top-N heapsort Memory: 31kB` para `ORDER BY facturacion DESC LIMIT 20` — no hay `Sort` de 3201kB del plan ANTES (desapareció al usar `Nested Loop` + índice ordenado).

---

## Explicación generada por IA — FICTICIA (pegada sin editar — contiene errores intencionales para el ejercicio)

> IA: **OpenCode (Muse Spark) — versión ficticia para el ejercicio** — Prompt: *"Explica este plan nodo por nodo, sin más contexto que el texto del plan. Diferenciá tabla externa/interna en Nested Loop (loops), build/probe en Hash Join, y señalá costo vs tiempo real. No confundas cost con actual time ni Buffers con filas."*
>
> **Respuesta IA (copiada textual — con errores intencionales):**
>
> 1. *"El nodo `Nested Loop (cost=1.42..4650.30, actual time=0.085..28.445)` tiene un costo de 4650.30 ms, lo que indica que tarda 4.6 segundos en ejecutarse. Es el nodo más lento del plan."*
> 2. *"La tabla externa del Nested Loop es `producto pr` (Index Scan con loops=48210) y la tabla interna es `pedido p` (Index Scan con loops=1). Como la interna se ejecuta 48210 veces, es la que más trabajo hace."*
> 3. *"Los `Buffers: shared hit=512 read=48` significan que se leyeron 512 filas de cache y 48 filas de disco, total 560 filas. Esto coincide con las 48210 filas del Nested Loop."*
> 4. *"El plan usa `Hash Join` con build en `pedido` (tabla grande hasheada en 4096kB) y probe en `detalle_pedido`. El `Batches 1 Memory 73kB` del HashAggregate muestra que el hash cabe en memoria."*
> 5. *"No hay `Sort` separado porque el `LIMIT 20` evita ordenar; el planner sabe que con LIMIT no hace falta ordenar todas las filas."*
> 6. *"El `Index Scan using idx_pedido_fecha_id` con `Index Cond: fecha BETWEEN` es correcto y evita el `Rows Removed by Filter: 150000` del plan anterior, reduciendo Buffers de 2890 a 210."*

---

## Tabla de contraste — Afirmación IA | ¿Correcta? | Corrección / evidencia del plan real

| # | Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real (línea exacta) |
|---|---|---|---|
| 1 | *"El nodo Nested Loop tiene un costo de 4650.30 ms, tarda 4.6 segundos. Es el nodo más lento."* | ❌ **No — confunde `cost` con `actual time`** | **Evidencia:** `Nested Loop  (cost=1.42..4650.30 rows=48210 width=48) (actual time=0.085..28.445 rows=48210 loops=1)`. `cost=1.42..4650.30` son **unidades del planner** (`seq_page_cost`), no ms. El tiempo real es `actual time=0.085..28.445 ms` (28ms total, no 4650ms). `Execution Time: 45.820 ms` es el total real. **Regla de oro §1:** decidir por `actual time`/`Execution Time`, no por `cost`. Si fuera 4650ms, el `Execution Time` no sería 45ms. |
| 2 | *"La tabla externa es `producto pr` (loops=48210) y la interna es `pedido p` (loops=1)."* | ❌ **No — invierte externa/interna** | **Evidencia:** `->  Index Scan using idx_pedido_fecha_id on pedido p  (cost=0.42..890.10 rows=48210 width=12) (actual time=0.028..4.102 rows=48210 **loops=1**)` ← **externa** (primer hijo del Nested Loop, `loops=1`, 48k filas). `->  Nested Loop  (cost=1.00..7.12 rows=1 width=36) (actual time=0.0004..0.0005 rows=1 **loops=48210**)` + `Index Scan on producto pr ... loops=48210` ← **interna** (`loops=48210`, una por fila externa). **Checklist:** `loops=1` = externa, `loops=N` = interna, tiempo total interna = `0.0005×48210 ≈ 24ms`. |
| 3 | *"Buffers hit=512 read=48 significa 512 filas de cache y 48 filas de disco, total 560 filas."* | ❌ **No — confunde páginas con filas** | **Evidencia:** `Buffers: shared hit=512 read=48` (pie del `Limit`) y `rows=20` (mismo nodo). `Buffers` son **páginas de 8KB**, no filas. `hit` = páginas ya en `shared_buffers`, `read` = páginas leídas de disco. Filas son `rows=20` (Limit) o `rows=48210` (Nested Loop). `512` páginas ≈ 4MB, no 512 filas. |
| 4 | *"El plan usa Hash Join con build en pedido (4096kB)." y "Batches 1 Memory 73kB del HashAggregate es el hash del join."* | ❌ **No — el plan DESPUÉS no tiene Hash Join; confunde HashAggregate con Hash Join** | **Evidencia:** el plan DESPUÉS **no contiene** `Hash Join` ni `Hash` con `Buckets/Memory 4096kB`; contiene `Nested Loop` + `HashAggregate  Batches: 1  Memory Usage: 73kB` que es **agregación** (`GROUP BY c.nombre, mes`), no hash de join. El `Hash Join` con `Memory 4096kB` existe solo en el **plan ANTES** Q1: `Hash  Buckets: 131072  Batches: 1  Memory Usage: 4096kB -> Seq Scan on detalle_pedido`. Confundir `HashAggregate` con `Hash` de join es error frecuente. |
| 5 | *"No hay Sort porque el LIMIT 20 evita ordenar."* | ⚠️ **Parcial — incompleta / engañosa** | **Evidencia:** sí hay `Sort`: `->  Sort  (cost=4890.20..4890.75 rows=220 width=64) (actual time=44.208..44.212 rows=20 loops=1) Sort Key: (sum(...)) DESC  Sort Method: top-N heapsort  Memory: 31kB`. `LIMIT` **no evita** ordenar cuando hay `ORDER BY facturacion DESC` sin índice que provea orden; el planner usa `top-N heapsort` (mantiene heap de 20 filas, no ordena todo). Lo que desapareció vs plan ANTES es el `Sort  Memory: 3201kB` del `Merge Join`, no el `Sort` del `ORDER BY`. |
| 6 | *"El Index Scan using idx_pedido_fecha_id con Index Cond evita Rows Removed 150000 y reduce Buffers 2890→210."* | ✅ **Sí — correcta** | **Evidencia:** `Index Scan using idx_pedido_fecha_id on pedido p  (cost=0.42..890.10 rows=48210 ...) Index Cond: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now())) Buffers: shared hit=210 read=15` vs plan ANTES `Seq Scan on pedido p  Filter: ((fecha >= ...) AND (fecha <= now())) Rows Removed by Filter: 150000 Buffers: shared hit=2890 read=210`. El `Index Cond` empuja el filtro al índice, `Rows Removed by Filter` pasa a 0, Buffers bajan 13×. **Esta afirmación es correcta y completa.** |

> **Resumen IA ficticia:** 1 correcta (afirmación 6), 3 erróneas por confusión `cost→ms` (af.1), inversión externa/interna (af.2), `Buffers→filas` (af.3), confusión `HashAggregate`↔`Hash Join` (af.4) y 1 incompleta (af.5). Mínimo exigido: 2 correctas + 1 errónea — aquí se documentan 6 para practicar.

## Aprendizaje para defensa oral — qué responder si te preguntan

- **"¿Externa vs interna?"** → mirar `loops`: `loops=1` es **externa** (se recorre una vez, primer hijo), `loops=N` es **interna** (se ejecuta N veces, segundo hijo). Tiempo total interna = `actual time (promedio por loop) × loops`. En Q1 DESPUÉS: externa `pedido p loops=1`, interna `producto pr loops=48210 × 0.0002ms ≈ 9.6ms`.
- **"¿Build vs probe?"** → build es el hijo `Hash` (`Seq/Index Scan → Hash  Buckets/Batches/Memory`), probe es el **otro hijo** del `Hash Join` (tabla grande que sondea). En Q1 ANTES: build `detalle_pedido` (200k → `Memory 4096kB`), probe `pedido` (Seq Scan 200k). `Batches 1` = entra en `work_mem`; `Batches >1` o `Disk:` = spill.
- **"¿Merge necesita orden?"** → sí, ambas entradas ordenadas por `Merge Cond`. Si ves `Sort` antes del `Merge Join`, el orden no viene del índice; si no hay `Sort`, viene de un índice ordenado `(col)`.
- **"¿cost vs ms?"** → `cost` es **planificación** (unidades abstractas, `seq_page_cost`), `actual time` es **ejecución medida** (ms). Decidir con `Execution Time` (45.820ms), no con `cost` (4890). `Planning Time` (2.105ms) es solo el tiempo del optimizador.
- **"¿Buffers?"** → `hit` = páginas 8KB en cache, `read` = páginas de disco; `rows` = filas. `Buffers 512` ≈ 4MB, no 512 filas.

## DUIA — uso IA en esta parte

| Herramienta | Para qué se usó | Prompt (resumen) | Se aceptó/descartó — por qué |
|---|---|---|---|
| OpenCode (Muse Spark) — ficticia | Explicar plan Q1 DESPUÉS nodo por nodo | *"Explica este plan nodo por nodo, solo con el texto del plan, diferenciando externa/interna (loops) o build/probe (Hash), sin confundir cost con actual time ni Buffers con filas."* | ⚠️ **Parcial / Descartada** — 3/6 afirmaciones con errores graves (`cost→ms`, externa/interna invertida, `Buffers→filas`, `HashAggregate` confundido con `Hash`). 1 correcta (Index Scan evita Rows Removed). Se corrigió con evidencia `loops`, `cost` vs `actual time`, `Buffers` §3. |
| Kiro — ficticia (contraste) | Explicar mismo plan Q1 DESPUÉS | *"Mismo plan que a OpenCode — explica nodos join y costo vs tiempo real, señalá Batches/Memory."* | ⚠️ **Parcial** — identificó bien `Batches 1 Memory 73kB` como `HashAggregate` (no join) y `top-N heapsort 31kB`, pero repitió error `cost=4890 ms` en Limit. Corrección idem. |

> **Trazabilidad:** plan Q1 DESPUÉS viene de `docs/optimizacion_tp4_parte1.md` §Q1 — mismo texto, sin edición. La IA solo recibió el bloque ` ```text` del plan, sin esquema ni índices.
