# Parte 1 — Laboratorio de joins analíticos — FoodStore (EJEMPLO SINTÉTICO VEROSÍMIL)

> UTN TUP BD II — Semana 4 — Parte 1 — Autor: Jerónimo Coronel — 2026-09-03 — **EJEMPLO SINTÉTICO para practicar flujo medir/proponer/medir**
> Base: `foodstore_trabajo` (50 030 productos, 20 020 clientes, 200 020 pedidos, 200 020 detalle_pedido) — `ANALYZE` aplicado — PostgreSQL 16.8
> Índices Semana 3 existentes: `idx_producto_categoria_activo_precio (producto id_categoria, activo, precio)`, `idx_pedido_cliente_fecha (pedido id_cliente, fecha)`, `idx_pedido_fecha (pedido fecha)`
> Esquema: `categoria(id_categoria, nombre, activo)`, `cliente(id_cliente, nombre, email, activo)`, `producto(id_producto, id_categoria, nombre, precio, stock, activo)`, `pedido(id_pedido, id_cliente, fecha, forma_pago)`, `detalle_pedido(id_pedido, id_producto, cantidad, precio_unitario)` — soft delete `activo BOOLEAN` en categoria/cliente/producto — FK `ON DELETE RESTRICT`
> **ADVERTENCIA:** Los planes `EXPLAIN (ANALYZE, BUFFERS)` de este documento son **sintéticos pero verosímiles**, generados para que el alumno practique la lectura sin depender de la base masiva real. El formato, los nodos y las métricas respetan la salida real de PostgreSQL 16. Diferencia explícita `cost` (estimado, unidades `seq_page_cost`) vs `actual time` (medido, ms).

## Protocolo obligatorio — medir antes / proponer con IA / medir después / decidir con datos

1. `EXPLAIN (ANALYZE, BUFFERS)` **ANTES** de cada cambio — plan completo en `C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q*_antes.txt` — copiar `cost` vs `actual time` y `Buffers: shared hit/read`.
2. Pasar plan a IA (OpenCode/Kiro) con prompt: *"Dado este plan EXPLAIN (ANALYZE, BUFFERS) de una consulta con JOIN de 3+ tablas en FoodStore (filtros `activo=TRUE`), proponé un índice o reescritura justificando qué nodo join atacás (externa/interna o build/probe) y qué cambio de algoritmo esperás (Hash → Nested Loop / Merge). No confundas cost con actual time."*
3. Aplicar `CREATE INDEX` o reescritura **solo si se entiende línea por línea** — `ANALYZE` sobre tablas tocadas + `EXPLAIN (ANALYZE, BUFFERS)` **DESPUÉS**.
4. Comparar nodo join (Nested Loop / Hash Join / Merge Join), `cost` estimado vs `actual time` real, `Buffers` y `Planning/Execution Time`.
5. Ningún cambio se acepta "porque lo dijo la IA": se acepta solo si la medición confirma mejora en `Execution Time` (tiempo real) y la justificación es defendible oralmente. **Gana menor `actual time`, no menor `cost`.**
6. Convenciones SQL: `activo = TRUE` donde corresponda (categoria/cliente/producto), sin `SELECT *`, `snake_case`, columnas explícitas, filtros de borrado lógico.

---

## Q1 — Facturación por categoría y mes (últimos 6 meses) — Consulta A — 4 JOINs + agregación + ORDER BY facturación

**Objetivo:** ranking de facturación mensual por categoría vigente, últimos 6 meses. 4 JOINs explícitos (`categoria → producto → detalle_pedido → pedido`), filtro temporal sobre `pedido.fecha`, agregación `sum(cantidad*precio_unitario)` y `count(DISTINCT pedido)`.

**SQL Q1 (idéntico al requerido en consigna — 4 JOINs):**
```sql
-- Q1 — Facturación por categoría y mes — 4 JOINs, >=3 tablas, filtros activo=TRUE
-- EXPLAIN (ANALYZE, BUFFERS) antes y después — foodstore_trabajo con ANALYZE
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

> Volumen estimado con datos masivos: `pedido` 200 020 filas (de ellas ~50k en últimos 6 meses, 150k fuera de rango → `Rows Removed by Filter: 150000`), `detalle_pedido` 200 020, `producto` 50 030 (45k activos), `categoria` 30 (28 activas).

### Plan ANTES — Q1 (sintético verosímil — sin índice propuesto)

```text
Limit  (cost=8124.55..8124.60 rows=20 width=64) (actual time=178.412..178.421 rows=20 loops=1)
  Buffers: shared hit=4821 read=312
  ->  Sort  (cost=8124.55..8125.10 rows=220 width=64) (actual time=178.410..178.415 rows=20 loops=1)
        Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
        Sort Method: top-N heapsort  Memory: 31kB
        Buffers: shared hit=4821 read=312
        ->  HashAggregate  (cost=8112.33..8118.93 rows=220 width=64) (actual time=177.102..177.389 rows=198 loops=1)
              Group Key: c.nombre, (date_trunc('month'::text, p.fecha))
              Batches: 1  Memory Usage: 73kB
              Buffers: shared hit=4821 read=312
              ->  Merge Join  (cost=1234.10..7890.45 rows=48210 width=48) (actual time=42.115..145.230 rows=48210 loops=1)
                    Merge Cond: (pr.id_categoria = c.id_categoria)
                    Buffers: shared hit=4821 read=312
                    ->  Sort  (cost=890.22..920.10 rows=45200 width=24) (actual time=18.210..22.445 rows=45200 loops=1)
                          Sort Key: pr.id_categoria
                          Sort Method: quicksort  Memory: 3201kB
                          Buffers: shared hit=1204 read=85
                          ->  Hash Join  (cost=1450.80..3210.55 rows=45200 width=24) (actual time=8.502..28.112 rows=45200 loops=1)
                                Hash Cond: (dp.id_producto = pr.id_producto)
                                Buffers: shared hit=1204 read=85
                                ->  Hash Join  (cost=4120.33..5890.12 rows=48210 width=28) (actual time=62.340..98.775 rows=48210 loops=1)
                                      Hash Cond: (dp.id_pedido = p.id_pedido)
                                      Buffers: shared hit=3610 read=227
                                      ->  Seq Scan on pedido p  (cost=0.00..3890.00 rows=200020 width=12) (actual time=0.015..48.112 rows=200020 loops=1)
                                            Filter: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now()))
                                            Rows Removed by Filter: 150000
                                            Buffers: shared hit=2890 read=210
                                      ->  Hash  (cost=2890.00..2890.00 rows=200020 width=16) (actual time=62.310..62.310 rows=200020 loops=1)
                                            Buckets: 131072  Batches: 1  Memory Usage: 4096kB
                                            Buffers: shared hit=720 read=17
                                            ->  Seq Scan on detalle_pedido dp  (cost=0.00..2890.00 rows=200020 width=16) (actual time=0.012..18.440 rows=200020 loops=1)
                                                  Buffers: shared hit=720 read=17
                                ->  Hash  (cost=890.00..890.00 rows=50030 width=12) (actual time=8.490..8.490 rows=50030 loops=1)
                                      Buckets: 65536  Batches: 1  Memory Usage: 2048kB
                                      Buffers: shared hit=484 read=12
                                      ->  Seq Scan on producto pr  (cost=0.00..890.00 rows=50030 width=12) (actual time=0.010..4.102 rows=50030 loops=1)
                                            Filter: (activo = TRUE)
                                            Rows Removed by Filter: 5030
                                            Buffers: shared hit=484 read=12
                    ->  Sort  (cost=12.10..12.60 rows=28 width=32) (actual time=0.045..0.051 rows=28 loops=1)
                          Sort Key: c.id_categoria
                          Sort Method: quicksort  Memory: 25kB
                          Buffers: shared hit=7
                          ->  Seq Scan on categoria c  (cost=0.00..11.40 rows=28 width=32) (actual time=0.008..0.022 rows=28 loops=1)
                                Filter: (activo = TRUE)
                                Rows Removed by Filter: 2
                                Buffers: shared hit=7
Planning Time: 1.842 ms
Execution Time: 180.512 ms
```

**Lectura nodo por nodo — Q1 ANTES (cost estimado vs tiempo real):**

| Nodo | Algoritmo | Externa / Interna o Build / Probe | `cost` estimado (unidades) | `actual time` real (ms) | `Buffers` | Observación |
|---|---|---|---|---|---:|---|
| `Hash Join (dp.id_pedido = p.id_pedido)` | **Hash Join** | **Build:** `detalle_pedido dp` (Seq Scan 200k → Hash `Batches 1 Memory 4096kB`, 131072 buckets) — tabla hasheada en memoria (pequeña relativa al probe filtrado) | `cost=4120.33..5890.12` | `actual time=62.340..98.775` | `hit=3610 read=227` | Build = `dp` (hash), Probe = `pedido p` (Seq Scan que sondea). Primer hijo del Hash Join es el **probe** (`Seq Scan on pedido`), segundo hijo `Hash` es el **build**. Elección del planner: hashea detalle (200k) porque cabe en `work_mem` (4MB, `Batches 1` sin spill). |
| `Hash Join (dp.id_producto = pr.id_producto)` | **Hash Join** | **Build:** `producto pr` (Seq Scan 50k → Hash `2048kB`) | `cost=1450.80..3210.55` | `actual time=8.502..28.112` | `hit=1204 read=85` | Build `pr`, Probe = resultado del Hash Join anterior (48k filas ya filtradas por fecha). |
| `Merge Join (pr.id_categoria = c.id_categoria)` | **Merge Join** | Requiere orden en `pr.id_categoria` y `c.id_categoria`. Ambas entradas pre-ordenadas vía `Sort` (`quicksort 3201kB` y `25kB`). | `cost=1234.10..7890.45` | `actual time=42.115..145.230` | `hit=4821 read=312` | Merge elegido porque `categoria` es tiny (28 filas) y `pr` ya se ordena para el Sort del Merge; si hubiera índice `(id_categoria)` ordenado, el Sort se evitaría. |
| `Seq Scan on pedido p` | **Seq Scan** | — | `cost=0.00..3890.00` | `actual time=0.015..48.112` | `hit=2890 read=210` | **Nodo más costoso en tiempo real.** Lee 200 020 filas, descarta 150 000 por `Filter: fecha BETWEEN` → `Rows Removed by Filter: 150000`. Sin índice sobre `fecha`, recorre heap completo. `cost` alto ~3890 pero `actual time` 48ms es el tiempo real de ese nodo; `cost` no son ms. |

> **Regla de oro:** `cost=8124.55` (estimado, unidades `seq_page_cost=1.0`) ≠ `actual time=178.412ms` (medido con `clock_gettime()`). El planner elige el plan de menor `cost`, el alumno elige el ganador por menor `Execution Time`.

**Nodo atacado y algoritmo join antes:**
- Algoritmo observado: `Hash Join (build detalle_pedido / probe pedido)` + `Hash Join (build producto)` + `Merge Join (categoria)`; `Sort` + `HashAggregate` + `top-N heapsort`.
- Nodo costoso: `Seq Scan on pedido p` con `Filter: fecha BETWEEN` — `Rows Removed by Filter: 150000`, `Buffers: shared hit=2890 read=210`, `actual time 48ms`, propaga costo a `Hash Join` padre (`actual 98ms`). Segundo costo: `Merge Join` con dos `Sort` (3201kB + 25kB).
- Por qué es costoso: sin índice que empuje el filtro `fecha` al acceso, se escanea heap completo; hash de 200k detalle en 4MB entra justo en `work_mem` (`Batches 1`), pero si creciera spillearía a disco.

**Propuesta justificada (qué nodo ataca, qué cambio de algoritmo espera):**
```sql
-- Propuesta Q1 — ataca Seq Scan + Filter sobre pedido.fecha y el Sort del Merge Join
-- Justificación IA (OpenCode): "El cuello de botella es el Seq Scan on pedido (48ms, 150k filas descartadas)
-- y el Sort previo al Merge Join. Un índice sobre pedido(fecha) permite Index Scan con Rows Removed 0
-- y un índice sobre producto(id_categoria, activo) INCLUDE (precio) evita Sort y hace el join más selectivo."

-- 1) Índice para el filtro temporal — permite Index Scan / Bitmap Heap Scan en lugar de Seq Scan
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_id
    ON pedido (fecha, id_cliente);
-- Ataca: Seq Scan on pedido -> espera: Index Scan using idx_pedido_fecha_id (Index Cond: fecha BETWEEN ...)
-- Buffers esperado: 2890 hit -> ~210 hit, Rows Removed by Filter: 150000 -> 0

-- 2) Índice para producto — orden y cobertura, evita Sort del Merge y reduce Hash
CREATE INDEX IF NOT EXISTS idx_producto_categoria_activo
    ON producto (id_categoria, activo) INCLUDE (precio);
-- Ataca: Seq Scan on producto + Sort (3201kB) -> espera: Bitmap Index Scan / Index Scan + desaparición del Sort
-- Permite que el planner pase el segundo Hash Join a Nested Loop si la selectividad lo justifica
-- (producto filtrado 45k -> 900/categoría) con Index Cond: pr.id_categoria = c.id_categoria

-- Mantenimiento
ANALYZE pedido;
ANALYZE producto;
ANALYZE categoria;
```

### Plan DESPUÉS — Q1 (con índices propuestos — cambio Hash Join → Nested Loop justificado)

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
                    -- Nota: categoria resuelta vía lookup indexado dentro del mismo Nested Loop externo
                    -- No hay Hash ni Sort de 3201kB: el orden lo provee idx_pedido_fecha_id
Planning Time: 2.105 ms
Execution Time: 45.820 ms
```

**Lectura nodo por nodo — Q1 DESPUÉS:**

| Nodo | Algoritmo | Externa / Interna | `cost` estimado | `actual time` real | `Buffers` |
|---|---|---|---|---|---:|
| `Index Scan on pedido p using idx_pedido_fecha_id` | **Index Scan** | **Externa** del Nested Loop superior (`loops=1`, 48k filas) | `cost=0.42..890.10` | `actual time=0.028..4.102` | `hit=210 read=15` | `Index Cond: fecha BETWEEN` — `Rows Removed by Filter: 0` (el índice ya filtra). Antes `Seq Scan` 200k filas / 150k descartadas; ahora 48k leídas. |
| `Nested Loop (pedido → detalle_pedido → producto)` | **Nested Loop** | **Externa:** `pedido p` (Index Scan, `loops=1`, 48k filas). **Interna:** `detalle_pedido dp` + `producto pr` (`loops=48210`, una por fila externa, `Index Cond: dp.id_pedido = p.id_pedido`) | `cost=1.42..4650.30` | `actual time=0.085..28.445` | `hit=512 read=48` | Cambio justificado: Hash Join (hash 4MB, `Batches 1`) → Nested Loop. Antes build 200k hash en memoria; ahora por cada pedido se hace `Index Scan` puntual (0.0003ms/loop). Total interna `0.0005*48210 ≈ 24ms` vs Hash `98ms`. `Buffers` 4821→512 (9× menos páginas). |
| `Index Scan on detalle_pedido` / `Index Scan on producto` | **Index Scan** | Internas (`loops=48210`) | `cost=0.42..2.10` / `0.28..4.45` | `actual 0.0002..0.0003` / `0.0001..0.0002` por loop | `hit=145` / `157` | `Index Cond` usa PK y `idx_producto_categoria_activo`; no hay `Rows Removed by Filter`. |
| `Sort + HashAggregate + Limit` | — | — | `cost 4890` | `actual 44ms` | `hit 512` | Mantiene `top-N heapsort 31kB`; el `Sort` de 3201kB del Merge desapareció. |

> **Diferencia cost vs tiempo real:** `cost` 8124→4890 (−40%) es estimación del planner (unidades abstractas). `Execution Time` 180.5ms→45.8ms (−75%, **4×**) es medición real — **criterio cátedra**. `Planning Time` sube 1.84→2.10ms por tener 2 índices más para planificar (irrelevante).

**Comparativa Q1:**

| Métrica | ANTES | DESPUÉS | Δ |
|---|---|---|---:|
| `cost` estimado (total) | `8124.55` | `4890.20` | **−39.8%** |
| `actual time` (Limit) | `178.412..178.421 ms` | `44.210..44.218 ms` | **−75.2%** |
| `Execution Time` | `180.512 ms` | `45.820 ms` | **3.94× más rápido** |
| `Buffers shared hit/read` | `4821 / 312` | `512 / 48` | **9.4× menos hit** |
| Algoritmo join | `Hash Join (build detalle, probe pedido)` + `Hash Join (build producto)` + `Merge Join (categoria)` con 2× Sort | `Nested Loop (externa pedido Index Scan, interna detalle+producto Index Scan)` — sin Hash ni Sort pesado | Cambio justificado |
| `Rows Removed by Filter (pedido)` | `150000` | `0` | Filtro empujado al índice |
| ¿Se acepta? | — | **✅ Sí** — mejora 4× en tiempo real, Buffers 9×, sin `Batches>1`/spill, defendible: selectividad `fecha` 24% + `loops` moderado (48k) hace Nested Loop óptimo. |

---

## Q2 — Ranking de clientes vigentes por gasto total (ventana RANK) — Consulta B — 4 JOINs + GROUP BY + WINDOW

**Objetivo:** reutilizable en Parte 3 — ranking de clientes por `total_gastado = sum(cantidad*precio_unitario)` con `RANK()`, empates comparten puesto, desempate determinístico `id_cliente ASC`.

**SQL Q2 (idéntico a consigna — 4 JOINs + ventana):**
```sql
-- Q2 — Ranking usuarios por gasto con ventana — 4 JOINs, ventana, filtros activo=TRUE
SELECT
    cli.id_cliente,
    cli.nombre,
    cli.email,
    sum(dp.cantidad * dp.precio_unitario)                           AS total_gastado,
    rank() OVER (ORDER BY sum(dp.cantidad * dp.precio_unitario) DESC) AS puesto
FROM cliente cli
JOIN pedido p           ON p.id_cliente = cli.id_cliente
JOIN detalle_pedido dp  ON dp.id_pedido = p.id_pedido
JOIN producto pr        ON pr.id_producto = dp.id_producto
WHERE cli.activo = TRUE
  AND pr.activo = TRUE
GROUP BY cli.id_cliente, cli.nombre, cli.email
ORDER BY total_gastado DESC
LIMIT 20;
```

### Plan ANTES — Q2 (sintético verosímil — sin índices parciales)

```text
Limit  (cost=15420.80..15420.85 rows=20 width=72) (actual time=248.102..248.110 rows=20 loops=1)
  Buffers: shared hit=6210 read=410
  ->  WindowAgg  (cost=15420.80..15480.10 rows=19400 width=72) (actual time=248.100..248.105 rows=20 loops=1)
        Buffers: shared hit=6210 read=410
        ->  Sort  (cost=15420.80..15469.30 rows=19400 width=64) (actual time=247.890..248.001 rows=19400 loops=1)
              Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
              Sort Method: quicksort  Memory: 120kB
              Buffers: shared hit=6210 read=410
              ->  HashAggregate  (cost=13890.10..14120.50 rows=19400 width=64) (actual time=180.220..210.445 rows=19400 loops=1)
                    Group Key: cli.id_cliente
                    Batches: 1  Memory Usage: 2048kB
                    Buffers: shared hit=6210 read=410
                    ->  Hash Join  (cost=2890.00..11200.45 rows=185000 width=40) (actual time=22.340..98.112 rows=185000 loops=1)
                          Hash Cond: (dp.id_producto = pr.id_producto)
                          Buffers: shared hit=6210 read=410
                          ->  Hash Join  (cost=1890.00..7890.33 rows=185000 width=36) (actual time=14.210..62.445 rows=185000 loops=1)
                                Hash Cond: (p.id_pedido = dp.id_pedido)
                                Buffers: shared hit=5420 read=380
                                ->  Hash Join  (cost=890.00..3890.55 rows=200020 width=16) (actual time=8.112..38.220 rows=200020 loops=1)
                                      Hash Cond: (p.id_cliente = cli.id_cliente)
                                      Buffers: shared hit=4320 read=310
                                      ->  Seq Scan on pedido p  (cost=0.00..1500.00 rows=200020 width=16) (actual time=0.010..12.445 rows=200020 loops=1)
                                            Buffers: shared hit=1500 read=110
                                      ->  Hash  (cost=620.00..620.00 rows=20020 width=32) (actual time=8.100..8.100 rows=20020 loops=1)
                                            Buckets: 32768  Batches: 1  Memory Usage: 2048kB
                                            Buffers: shared hit=420 read=20
                                            ->  Parallel Seq Scan on cliente cli  (cost=0.00..620.00 rows=20020 width=32) (actual time=0.020..4.880 rows=20020 loops=1)
                                                  Filter: (activo = TRUE)
                                                  Rows Removed by Filter: 620
                                                  Buffers: shared hit=420 read=20
                                ->  Hash  (cost=1500.00..1500.00 rows=200020 width=16) (actual time=14.200..14.200 rows=200020 loops=1)
                                      Buckets: 131072  Batches: 1  Memory Usage: 5120kB
                                      Buffers: shared hit=1100 read=70
                                      ->  Seq Scan on detalle_pedido dp  (cost=0.00..1500.00 rows=200020 width=16) (actual time=0.012..8.112 rows=200020 loops=1)
                                            Buffers: shared hit=1100 read=70
                          ->  Hash  (cost=620.00..620.00 rows=50030 width=12) (actual time=8.120..8.120 rows=50030 loops=1)
                                Buckets: 65536  Batches: 1  Memory Usage: 2048kB
                                Buffers: shared hit=790 read=30
                                ->  Seq Scan on producto pr  (cost=0.00..620.00 rows=50030 width=12) (actual time=0.011..3.990 rows=50030 loops=1)
                                      Filter: (activo = TRUE)
                                      Rows Removed by Filter: 5030
                                      Buffers: shared hit=790 read=30
Planning Time: 1.520 ms
Execution Time: 250.340 ms
```

**Lectura — Q2 ANTES:**

| Nodo | Algoritmo | Build / Probe o Externa/Interna | `cost` | `actual time` | Buffers | Nota |
|---|---|---|---:|---|---:|---|
| `Parallel Seq Scan on cliente cli` | Seq Scan paralelo | Build del primer Hash Join | `cost=0.00..620` | `actual 0.02..4.88` | `420/20` | Lee 20 020, descarta 620 (`activo=TRUE` falso) → `Rows Removed: 620`. |
| `Hash Join p.id_cliente = cli.id_cliente` | Hash Join | **Build:** `cliente` (20k hash 2048kB), **Probe:** `pedido` (200k) | `cost 890..3890` | `actual 8..38ms` | — |  |
| `Hash Join p.id_pedido = dp` | Hash Join | **Build:** `detalle_pedido` (200k, 5120kB) | `cost 1890..7890` | `actual 14..62ms` | — |  |
| `Hash Join dp.id_producto = pr` | Hash Join | **Build:** `producto` (50k, 2048kB) | `cost 2890..11200` | `actual 22..98ms` | `6210/410` | Nodo dominante. |
| `HashAggregate` + `Sort (quicksort 120kB)` + `WindowAgg` | — | — | `cost 13890..15480` | `actual 180..248ms` | — | `Sort` para `RANK() OVER (ORDER BY sum DESC)` — quicksort 120kB en memoria, sin spill. |

> `cost=15420.80` (estimado) ≠ `actual time=248.102ms` (medido). `Buffers: 6210` páginas 8KB ≈ 49MB leídos.

**Nodo atacado:** triple Hash Join encadenado + `Parallel Seq Scan` con filtro `activo`.

**Propuesta justificada Q2:**
```sql
-- Propuesta Q2 — ataca Parallel Seq Scan con filtro activo y el Hash Join cliente→pedido
-- El índice existente idx_pedido_cliente_fecha ya indexa (id_cliente, fecha) pero no es parcial por activo.
-- Dos índices nuevos / reutilizados:

-- 1) Índice parcial para clientes vigentes — evita leer 620 inactivos + permite Index Scan
CREATE INDEX IF NOT EXISTS idx_cliente_activo_true
    ON cliente (id_cliente) WHERE activo = TRUE;
-- Ataca: Parallel Seq Scan on cliente (Rows Removed 620) -> Index Scan / Bitmap Heap Scan con 0 removidas
-- Estimación: Seq 20k -> Index 19400 filas vigentes, Buffers 420 -> ~110

-- 2) Reutiliza idx_pedido_cliente_fecha (pedido id_cliente, fecha) — ya existe Semana 3
-- No hace falta crear de nuevo, pero se fuerza su uso: el planner pasará el primer Hash Join a Nested Loop
-- cuando el cliente es externo con loops=19400 y cada pedido promedia ~10 por cliente.

-- 3) Opcional: índice ya propuesto idx_producto_categoria_activo reutilizado para pr.activo
-- Ataca: Seq Scan producto 50k -> Index Scan parcial

ANALYZE cliente;
ANALYZE pedido;
```

### Plan DESPUÉS — Q2 (con índices parciales — Nested Loop + Index Scan)

```text
Limit  (cost=8920.30..8920.35 rows=20 width=72) (actual time=59.802..59.810 rows=20 loops=1)
  Buffers: shared hit=1820 read=85
  ->  WindowAgg  (cost=8920.30..8980.10 rows=19400 width=72) (actual time=59.800..59.805 rows=20 loops=1)
        Buffers: shared hit=1820 read=85
        ->  Sort  (cost=8920.30..8968.80 rows=19400 width=64) (actual time=59.590..59.701 rows=19400 loops=1)
              Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
              Sort Method: quicksort  Memory: 120kB
              Buffers: shared hit=1820 read=85
              ->  HashAggregate  (cost=7620.10..7820.50 rows=19400 width=64) (actual time=42.220..52.445 rows=19400 loops=1)
                    Group Key: cli.id_cliente
                    Batches: 1  Memory Usage: 2048kB
                    Buffers: shared hit=1820 read=85
                    ->  Nested Loop  (cost=1.20..5200.45 rows=185000 width=40) (actual time=0.045..28.112 rows=185000 loops=1)
                          Buffers: shared hit=1820 read=85
                          ->  Index Scan using idx_cliente_activo_true on cliente cli  (cost=0.12..420.10 rows=19400 width=32) (actual time=0.015..2.112 rows=19400 loops=1)
                                Buffers: shared hit=110 read=5
                          ->  Index Scan using idx_pedido_cliente_fecha on pedido p  (cost=0.42..2.80 rows=10 width=16) (actual time=0.0010..0.0012 rows=10 loops=19400)
                                Index Cond: (p.id_cliente = cli.id_cliente)
                                Buffers: shared hit=820 read=40
                          -- Hash Join restante para detalle/producto se mantiene (o pasa a Nested Loop según selectividad)
                          -- Para brevedad, el subárbol detalle→producto se muestra colapsado como Bitmap Heap Scan
                          ->  Bitmap Heap Scan on detalle_pedido dp  (cost=4.10..12.20 rows=10 width=16) (actual time=0.0008..0.0010 rows=10 loops=19400)
                                Recheck Cond: (dp.id_pedido = p.id_pedido)
                                Buffers: shared hit=890 read=40
Planning Time: 1.980 ms
Execution Time: 60.120 ms
```

**Lectura — Q2 DESPUÉS:**

| Métrica | ANTES | DESPUÉS | Δ |
|---|---|---|---:|
| `cost` estimado | `15420.80` | `8920.30` | **−42.1%** |
| `Execution Time` | `250.340 ms` | `60.120 ms` | **4.16× más rápido** |
| `Buffers hit/read` | `6210 / 410` | `1820 / 85` | **3.4× menos** |
| `Parallel Seq Scan cliente` | `Rows Removed 620`, `hit 420` | `Index Scan idx_cliente_activo_true`, `Rows Removed 0`, `hit 110` | Filtro empujado |
| Algoritmo join principal | `Hash Join (build cliente 20k)` | `Nested Loop (externa cliente Index Scan loops=1 → interna pedido Index Scan loops=19400)` | Cambio justificado: `loops` 19k con 10 filas/loop → `0.0012ms*19400 ≈ 23ms` < Hash 38ms |
| `Sort quicksort 120kB` | presente | presente (ventana requiere orden) | No evitable sin índice sobre `sum` (agregado) |

> **Justificación del cambio Hash → Nested Loop:** con índice `idx_pedido_cliente_fecha(id_cliente, fecha)` el planner estima `rows=10` por cliente (200k pedidos / 19.4k clientes vigentes). `Nested Loop` con `Index Scan` interno hace `19400 loops * 0.0012ms ≈ 23ms` + `Index Scan` externo 2ms < `Hash Join` 38ms que hashea 20k clientes (2048kB) + escanea 200k pedidos. `Buffers` y `cost` bajan en proporción.

---

## Tabla comparativa Parte 1 — entrega

| Consulta | Algoritmo join **antes** | Cambio aplicado | Algoritmo join **después** | `cost` antes → después | `Execution Time` antes → después | `Buffers hit` antes → después | Mejora (×) | ¿Aceptado? |
|---|---|---|---|---|---|---|---|---|
| **Q1** Facturación categoría×mes (4 JOINs) | `Hash Join (build detalle 4MB)` + `Hash Join (build producto 2MB)` + `Merge Join` + 2×Sort (3201kB) — `cost 8124`, `actual 178ms`, `Buffers 4821` | `CREATE INDEX idx_pedido_fecha_id ON pedido(fecha,id_cliente)` + `CREATE INDEX idx_producto_categoria_activo ON producto(id_categoria,activo) INCLUDE(precio)` + `ANALYZE` | `Nested Loop (externa pedido Index Scan loops=1, interna detalle+producto Index Scan loops=48210)` + sin Sort 3201kB — `cost 4890`, `actual 44ms`, `Buffers 512` | `8124 → 4890` (−40%) | `180.5ms → 45.8ms` | `4821 → 512` | **3.94×** | ✅ **Sí** — `Rows Removed 150k→0`, Buffers 9×, 4× tiempo real, sin spill `Batches 1` |
| **Q2** Ranking clientes por gasto (ventana RANK) | `Hash Join ×3` (build cliente 2MB, detalle 5MB, producto 2MB) + `HashAggregate` + `Sort quicksort 120kB` + `WindowAgg` — `cost 15420`, `actual 248ms`, `Buffers 6210` | `CREATE INDEX idx_cliente_activo_true ON cliente(id_cliente) WHERE activo=TRUE` + reuso `idx_pedido_cliente_fecha` + `ANALYZE` | `Nested Loop (externa cliente Index Scan, interna pedido Index Scan loops=19400)` + `Bitmap Heap Scan` detalle — `cost 8920`, `actual 59ms`, `Buffers 1820` | `15420 → 8920` (−42%) | `250.3ms → 60.1ms` | `6210 → 1820` | **4.16×** | ✅ **Sí** — `Rows Removed 620→0`, Nested Loop óptimo con `loops` moderado y `Index Cond` selectivo |

> **Criterio cátedra:** gana menor `actual time` / `Execution Time` (tiempo real medido), **no** menor `cost` estimado. `cost` explica por qué el planner eligió el plan; `Execution Time` decide. Documentar "qué se esperaba, qué pasó, por qué" aunque no haya mejora — en este ejemplo ambas mejoras superan 4×.

## Archivos de evidencia (flujo completo medido)

- Planes antes: `C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q1_antes.txt` (Q1 ANTES arriba), `C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q2_antes.txt` (Q2 ANTES)
- Planes después: `C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q1_despues.txt` (Q1 DESPUÉS), `C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q2_despues.txt` (Q2 DESPUÉS)
- Índices y tamaños:
```sql
SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid)) AS tamano
FROM pg_stat_user_indexes
WHERE relname IN ('producto','pedido','cliente','categoria','detalle_pedido')
ORDER BY relname, indexname;
-- Esperado: idx_pedido_fecha_id ~ 8 MB, idx_producto_categoria_activo ~ 3 MB, idx_cliente_activo_true ~ 400 kB
```
- `ANALYZE` aplicado antes de cada `EXPLAIN (ANALYZE, BUFFERS)` — sin `ANALYZE`, el planner subestima `rows` y elige Hash cuando conviene Nested Loop.

## Declaración IA — Parte 1 (resumen trazable)

| Herramienta | Para qué se usó | Prompt (resumen) | Se aceptó/descartó — por qué |
|---|---|---|---|
| OpenCode (Muse Spark) | Proponer índices Q1/Q2 | "Dado este plan EXPLAIN (ANALYZE, BUFFERS) con JOIN 3+ tablas, proponé índice/reescritura justificando nodo join atacado y cambio de algoritmo esperado. Filtros activo=TRUE." | ✅ **Aceptado** — propuesta `idx_pedido_fecha_id` + `idx_producto_categoria_activo` ataca `Seq Scan` con 150k `Rows Removed` y `Sort` 3201kB; medición confirma 4×. |
| Kiro | Segunda opinión Q2 | "Misma consulta y plan que a OpenCode — proponé alternativa distinta, justificá nodo build/probe." | ⚠️ **Parcial** — propuso `COVERING INDEX` con `INCLUDE` total, descartado por tamaño (duplica heap) sin cambiar algoritmo; se adoptó índice parcial `WHERE activo=TRUE` más liviano. |

> Detalle completo DUIA en `docs/DUIA_TP4.md`. Ningún cambio se aceptó sin `EXPLAIN (ANALYZE, BUFFERS)` antes/después y sin entender `loops` (externa `loops=1` vs interna `loops=N`, tiempo total interna = `actual time × loops`).
