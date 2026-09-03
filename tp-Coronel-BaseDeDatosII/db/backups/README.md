# Backups — FoodStore
Directorio versionado para dumps de PostgreSQL.

- Guardar dumps con: `pg_dump -Fc -f db/backups/foodstore_trabajo_YYYYMMDD.dump foodstore_trabajo`
- Texto plano opcional: `pg_dump -f db/backups/foodstore_trabajo_YYYYMMDD.sql foodstore_trabajo`
- Nomenclatura: `foodstore_trabajo_YYYYMMDD.dump` (ej: 20260903) o `YYYYMMDD_HHMM` si hay dos en el día.
- Retención mínima: último dump diario + dump previo a cada entrega.
- Los `*.dump` binarios grandes están ignorados por `.gitignore`; commitear solo `.sql` livianos si hace falta.
- Ver `docs/protocolo_seguridad.md` §2 y §3 para flujo obligatorio (mkdir -p db/backups + pg_dump previo a cada DDL/DML).

Restaurar: `pg_restore -d foodstore_trabajo db/backups/foodstore_trabajo_YYYYMMDD.dump`
