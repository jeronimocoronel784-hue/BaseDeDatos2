# tp-Coronel-BaseDeDatosII — Base de Datos II — UTN TUP

> **Autor:** Jerónimo Coronel — **Fecha:** 2026-09-03 — **Motor:** PostgreSQL 16 — **Esquema:** FoodStore

## Estructura

```
tp-Coronel-BaseDeDatosII/
├── AGENTS.md                         # Convenciones del repo (ruta core: db/schema.sql)
├── README.md                         # Este archivo
├── .env.example                      # Variables PG para local (copiar a .env)
├── .gitignore                        # Ignora db/backups/*.dump y .env
├── db/
│   ├── schema.sql                    # DDL base FoodStore (categoria, cliente, producto, pedido, detalle_pedido)
│   ├── restricciones_foodstore.sql   # Parte 1 — 3 reglas (R1 fecha futura, R2 stock/activo FOR UPDATE, R3 precio/email)
│   └── backups/
│       ├── .gitkeep
│       └── README.md                 # Instrucciones pg_dump -Fc
├── docs/
│   ├── protocolo_seguridad.md        # Parte 0 — copia + transacción + respaldo (adaptado a createdb -T / pg_dump)
│   ├── informe_concurrencia.md       # Parte 2 — 3 escenarios (no repetible, phantom, FOR UPDATE/bloqueo + deadlock 40P01)
│   ├── ejercicio_lectura_critica.md  # Parte 3 — corrección Script 1 UPDATE sin WHERE y Script 2 NOT IN vs NOT EXISTS
│   ├── DUIA_Parte1.md                # DUIA Parte 1 (restricciones)
│   └── DUIA_Parte2.md                # DUIA Parte 2 (concurrencia)
└── src/
    └── .gitkeep
```

## Entregables — Checklist

- [x] **Parte 0** `docs/protocolo_seguridad.md` — commiteado antes de Parte 1 (copia `createdb -T`, `BEGIN/ROLLBACK`, `pg_dump -Fc db/backups/`)
- [x] **Parte 1** `db/restricciones_foodstore.sql` + `docs/DUIA_Parte1.md` — 3 reglas idempotentes con triggers/CHECKs
- [x] **Parte 2** `docs/informe_concurrencia.md` + `docs/DUIA_Parte2.md` — RC vs RR, phantom, FOR UPDATE + pg_locks / 40P01
- [x] **Parte 3** `docs/ejercicio_lectura_critica.md` — análisis y corrección de 2 scripts IA peligrosos (UPDATE sin WHERE, NOT IN con NULL)
- [x] `db/schema.sql` — esquema base FoodStore
- [x] `AGENTS.md` — convenciones (chk_*, fk_*, ON DELETE RESTRICT, activo BOOLEAN)
- [ ] **TP4 Parte 1** `docs/optimizacion_tp4_parte1.md` — laboratorio joins analíticos (2 consultas >=3 tablas, EXPLAIN ANALYZE, tabla comparativa Consulta | Algoritmo join antes | Cambio | Algoritmo después | Mejora)
- [ ] **TP4 Parte 2** `docs/lectura_critica_tp4_parte2.md` — lectura crítica nodos join (externa/interna Nested Loop, Hash build/probe, Merge, cost vs actual time)
- [ ] **TP4 Parte 3** `db/consultas_tp4_parte3.sql` — specs precisas ranking ventana + subconsulta correlacionada con verificación EXCEPT bidireccional
- [ ] **TP4 Parte 4** `docs/competencia_tp4_parte4.md` + `docs/DUIA_TP4.md` — competencia (Equipo | Estrategia | Tiempo antes/despues | Mejora x) y DUIA (Herramienta | Para qué | Prompt | Aceptado/descartado)

## Quickstart

```bash
# Setup inicial (una vez)
createdb foodstore_original
psql -d foodstore_original -f db/schema.sql
mkdir -p db/backups; pg_dump -Fc -f db/backups/foodstore_original_20260903.dump foodstore_original

# Trabajo diario (protocolo obligatorio)
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
mkdir -p db/backups; pg_dump -Fc -f db/backups/foodstore_trabajo_20260903.dump foodstore_trabajo
psql -d foodstore_trabajo -c "BEGIN; \i db/restricciones_foodstore.sql; ROLLBACK;"  # verificar
psql -d foodstore_trabajo -c "BEGIN; \i db/restricciones_foodstore.sql; COMMIT;"   # si OK
```

Ver `docs/protocolo_seguridad.md` §3 y §4 para flujo DDL/DML completo y `docs/informe_concurrencia.md` para reproducir los 3 escenarios.
