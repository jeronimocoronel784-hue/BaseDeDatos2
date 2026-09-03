# Parte 4 — Consultas resumen y subconsultas bajo especificación precisa

> UTN TUP BD II — Semana 3 — Autor: Jerónimo Coronel — 2026-09-03
> Base: foodstore_trabajo (50030 productos, 20020 clientes, 200020 pedidos)

## Metodología (PDF p3-4)

1. Redactar spec precisa (tablas, filtro borrado lógico, columnas salida, orden, corte LIMIT/HAVING)
2. Pedir a IA que genere SQL sin mostrar solución previa
3. Escribir versión propia alternativa (subconsulta vs JOIN)
4. Verificar equivalencia con `EXCEPT` en ambas direcciones (0 filas)

Archivo SQL canónico: `db/consultas_tp3_parte4.sql` — ejecutable y verificado en `foodstore_trabajo`.

---

## Spec 1 — Resumen (agregación)

**Spec entregada a IA (texto exacto):**
> "Genera una consulta SQL sobre FoodStore que devuelva, para cada categoría VIGENTE (categoria.activo=TRUE), el nombre de la categoría y la cantidad de productos VIGENTES (producto.activo=TRUE) que tiene, INCLUYENDO categorías sin productos vigentes con cantidad 0. Columnas: categoria_nombre (categoria.nombre), cantidad_productos (COUNT). Ordená de mayor a menor cantidad, desempate alfabético por categoria_nombre. No uses SELECT *."

**Versión A — IA (JOIN LEFT + GROUP BY):**
```sql
SELECT c.nombre AS categoria_nombre, count(p.id_producto) AS cantidad_productos
FROM categoria c LEFT JOIN producto p ON p.id_categoria=c.id_categoria AND p.activo=TRUE
WHERE c.activo=TRUE GROUP BY c.id_categoria, c.nombre
ORDER BY cantidad_productos DESC, categoria_nombre ASC;
```

**Versión B — Alternativa propia (subconsulta correlacionada):**
```sql
SELECT c.nombre AS categoria_nombre,
       (SELECT count(*) FROM producto p WHERE p.id_categoria=c.id_categoria AND p.activo=TRUE) AS cantidad_productos
FROM categoria c WHERE c.activo=TRUE
ORDER BY cantidad_productos DESC, categoria_nombre ASC;
```

**Verificación (foodstore_trabajo 2026-09-03):**
```
categoria_nombre | cantidad_productos
Lácteos          | 5956
Carnes           | 5954
...
Frutas           | 5882  (8 filas, ambas versiones idénticas)

A EXCEPT B → 0 filas
B EXCEPT A → 0 filas
```
**Conclusión:** Equivalentes. La versión B con subconsulta es válida pero el planner la reescribe a JOIN (EXPLAIN muestra Hash Join en ambos casos). Se elige A por claridad y mejor plan (un solo HashAggregate vs 8 Index Scans correlacionados).

---

## Spec 2 — Subconsulta (clientes sin pedidos)

**Spec entregada a IA (texto exacto):**
> "Genera una consulta SQL sobre FoodStore que devuelva los clientes vigentes (cliente.activo=TRUE) que NUNCA hicieron un pedido (no existe pedido con id_cliente = cliente.id_cliente). Tablas: cliente, pedido. Columnas: id_cliente, nombre, email. Filtro borrado lógico en cliente. Ordená por id_cliente ASC. No uses SELECT *."

**Versión A — IA (NOT EXISTS — recomendada, inmune a NULL):**
```sql
SELECT id_cliente, nombre, email FROM cliente c
WHERE c.activo=TRUE AND NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_cliente=c.id_cliente)
ORDER BY id_cliente ASC;
```

**Versión B — Alternativa propia (LEFT JOIN + IS NULL):**
```sql
SELECT c.id_cliente, c.nombre, c.email FROM cliente c
LEFT JOIN pedido p ON p.id_cliente=c.id_cliente
WHERE c.activo=TRUE AND p.id_pedido IS NULL
ORDER BY c.id_cliente ASC;
```

**Variante descartada — NOT IN (vulnerable a NULL):**
```sql
-- SELECT ... WHERE id_cliente NOT IN (SELECT id_cliente FROM pedido)
-- Si pedido.id_cliente tuviera NULL, NOT IN retorna 0 filas por lógica trivaluada (UNKNOWN)
-- Se descarta, se documenta en ejercicio_lectura_critica.md
```

**Verificación (foodstore_trabajo 2026-09-03):**
```
A → 0 filas
B → 0 filas
A EXCEPT B → 0 filas
B EXCEPT A → 0 filas
```
**Nota técnica:** Tras la carga masiva (20020 clientes, 200020 pedidos distribuidos round-robin), TODOS los clientes activos tienen ≥9 pedidos, por lo que el conjunto "clientes sin pedidos" es vacío. La equivalencia sigue siendo válida (∅ EXCEPT ∅ = ∅). En una base seed pequeña (20 clientes, 20 pedidos) esta misma spec devolvería ~5-10 filas y la equivalencia se verificaría con filas reales. Se mantiene como demostración de `NOT EXISTS` vs `LEFT JOIN` y manejo de `NULL`.

**Plan comparado:** Ambas usan `Hash Anti Join` (NOT EXISTS) o `Hash Left Join + Filter IS NULL` — mismo costo. Se prefiere `NOT EXISTS` por ser inmune a `NULL` y más legible.

---

## Evidencia de ejecución

```sql
psql -d foodstore_trabajo -f db/consultas_tp3_parte4.sql
-- Salida: 8 filas Spec 1, 0/0 EXCEPT, 0 filas Spec 2, 0/0 EXCEPT — ver log arriba
```

## DUIA — uso IA en esta parte

| Herramienta | Para qué se usó | Prompt (resumen) | Se aceptó/descartó — por qué |
|---|---|---|---|
| Muse Spark | Generar Versión A Spec 1 (JOIN LEFT) | Spec 1 textual (ver arriba) | ✅ Aceptada — cumple tablas, filtros, columnas, orden, sin SELECT * |
| Muse Spark | Generar Versión A Spec 2 (NOT EXISTS) | Spec 2 textual | ✅ Aceptada — usa NOT EXISTS inmune a NULL, orden correcto |
| Propia | Versión B Spec 1 (subconsulta correlacionada) | Reescritura manual | ✅ Alternativa equivalente, EXCEPT 0, se compara plan |
| Propia | Versión B Spec 2 (LEFT JOIN IS NULL) | Reescritura manual | ✅ Alternativa equivalente, EXCEPT 0, se documenta NOT IN descartado |
