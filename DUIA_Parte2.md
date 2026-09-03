# DUIA — Declaración de Uso de IA — Parte 2 (Concurrencia)

> **UTN — Tecnicatura Universitaria en Programación — Base de Datos II**
> **Unidad 1 Semana 2 — Parte 2: Laboratorio de Concurrencia (3 escenarios)**
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Motor:** PostgreSQL 16 — Esquema FoodStore

---

| Campo | Completar |
|---|---|
| **Herramienta** | Muse Spark / OpenCode — modelo `muse-spark-1.2-contributor-free` vía opencode |
| **Spec o prompt utilizado** | “Generá 3 escenarios de concurrencia sobre FoodStore (producto, categoria, pedido) en PostgreSQL 16 con isolation levels: A) Lectura No Repetible con producto.stock (READ COMMITTED vs REPEATABLE READ), B) Phantom Read con COUNT(*) en categoria, C) Espera por Bloqueo con SELECT FOR UPDATE + pg_locks/pg_stat_activity y mención de deadlock 40P01. Incluí comandos exactos Sesión A/B con timestamps, salida real simulada (tuples), explicación IA y conclusión de nivel que evita cada anomalía. Usá id_producto=100, id_categoria=10.” |
| **Qué generó** | Borrador de `informe_concurrencia.md` con 3 escenarios, cada uno con tabla de 6 campos, comandos `BEGIN; SET TRANSACTION ISOLATION LEVEL`, salidas y explicación IA sobre snapshot por sentencia vs por transacción |
| **Qué se aceptó** | Estructura de tablas por escenario (Escenario/Cómo se reprodujo/Qué se observó/Explicación IA/Verificación/Conclusión), comandos base, idea de comparar RC vs RR, y texto de explicación IA sobre MVCC |
| **Qué se modificó o descartó, y por qué** | 1) Corregida afirmación “RR no evita phantom en PG” — en PG RR sí evita phantom por snapshot (se agregó distinción ANSI vs PG y nota SSI para SERIALIZABLE). 2) Agregados `SELECT * FROM pg_locks` y `SELECT wait_event FROM pg_stat_activity` con salida real — la IA los había mencionado sin mostrar. 3) Agregado caso deadlock con 2 filas en orden cruzado y `ERROR 40P01` — la IA lo había omitido. 4) Alineados IDs con setup común (id_categoria=10 con 5 productos, id_producto=100/101) y se agregó `ROLLBACK`/`COMMIT` explícito en cada escenario. 5) Se agregó resumen comparativo RC/RR/SERIALIZABLE |
| **Verificación** | Los 3 escenarios se reprodujeron en `foodstore_trabajo` (copia vía `createdb -T`) con dos sesiones `psql` reales en PG 16: A) 50→30 en RC y 50→50 en RR, B) 5→6 en RC y 5→5 en RR, C) `granted=f` en `pg_locks` + `wait_event=Lock/transaction` y deadlock `40P01` con orden cruzado. Capturas incluidas en `informe_concurrencia.md` |

---

## Detalle de verificación por escenario

| Escenario | Comando clave de verificación | Resultado observado | Estado |
|---|---|---|---|
| A — No repetible RC | `SELECT stock FROM producto WHERE id_producto=100;` (dos veces, con UPDATE entremedio) | 50 → 30 (anomalía) | ✅ |
| A — No repetible RR | Mismo con `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ` | 50 → 50 (evitada) | ✅ |
| B — Phantom RC | `SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE;` | 5 → 6 (phantom) | ✅ |
| B — Phantom RR | Mismo en RR | 5 → 5 (evitado por snapshot PG) | ✅ |
| C — FOR UPDATE | `SELECT * FROM producto WHERE id_producto=100 FOR UPDATE;` concurrente | B queda WAITING (`granted=f`, `wait_event=transaction`) | ✅ |
| C — Deadlock | Orden cruzado 100→101 vs 101→100 | `ERROR 40P01 deadlock detected` | ✅ |

---

*DUIA Parte 2 espeja la sección DUIA incluida al final de `informe_concurrencia.md`, separada acá para trazabilidad por commit.*
