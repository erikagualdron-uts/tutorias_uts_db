# tutorias_uts_db
## Datos de volumen (spec 023)

`npm run seed:load` carga datos sintéticos del tamaño de una institución (200 módulos, 4.800 sesiones, unas 3.500 inscripciones, 200 PQRS, 541 cuentas, 200 conversaciones y 4.000 mensajes) para medir rendimiento. Es determinista y se niega a correr si la base no se llama `*_load` o falta `LOAD_SEED_CONFIRM=yes`; nunca se usa en producción.

```bash
docker compose exec postgres createdb -U uts tutorias_load
DATABASE_URL=<url de tutorias_load> npm run migrate:deploy
LOAD_SEED_CONFIRM=yes DATABASE_URL=<url de tutorias_load> npm run seed:load
```

Cuentas fijas, todas con la clave `Clave1234`: `cae@correo.uts.edu.co`, `docente0@correo.uts.edu.co` (4 módulos en el periodo activo) y `estudiante0@uts.edu.co` (10 inscripciones). La base debe estar vacía; para repetir la carga, se borra y se vuelve a crear.
