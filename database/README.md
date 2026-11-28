# Base de datos de Waypoint

MySQL 8.4 con 7 tablas. El esquema lo manejan las migraciones de Prisma (`backend/prisma/`). Esta carpeta tiene el modelo, el script completo y los acuerdos con la API.

## Archivos

| Archivo | Qué es |
|---|---|
| `modelo_er.png` | Diagrama entidad-relación final |
| `waypoint.mwb` | El modelo en MySQL Workbench, del que sale el diagrama |
| `waypoint.sql` | El esquema final completo en un solo script: tablas, llaves foráneas, índices y `CHECK`. Es el mismo que dejan las migraciones |
| `acuerdos-bd-api.md` | Decisiones de la BD que afectan a la API (roles, contraseñas, estados, evidencias) |
| `init/01-shadow.sql` | Lo corre Docker la primera vez: crea `waypoint_shadow`, la BD auxiliar que usa `npm run db:migrate` |

El esquema "oficial" son las migraciones de `backend/prisma/migrations/` (`esquema_inicial` y `revision_restricciones`). `waypoint.sql` es una copia para leerlo de corrido o para crear la BD sin Node.

## Modelo

![Diagrama entidad-relación](modelo_er.png)

| Tabla | Guarda | Se relaciona con |
|---|---|---|
| `roles` | `usuario` y `operador` | `usuarios` |
| `usuarios` | Cuentas. El correo es único sin importar mayúsculas y la contraseña es un hash de bcrypt | `roles`; crea `reportes`, los atiende como operador, sube `evidencias` y hace movimientos en `historial` |
| `categorias` | Tipos de barrera (rampa, elevador, señalización...) | `reportes` |
| `estados` | Los 4 pasos de un reporte, con su orden: Reportado (1) → En análisis (2) → En atención (3) → Resuelto (4) | `reportes` (estado actual) e `historial` (estado anterior y nuevo) |
| `reportes` | Cada barrera reportada: texto, ubicación, coordenadas opcionales, estado, operador asignado y si se canceló | `usuarios` (dos veces: creador y operador), `categorias`, `estados` |
| `evidencias` | Las fotos: las del reporte (`reporte`) y las de la atención (`atencion`) | `reportes`, `usuarios` |
| `historial` | Cada movimiento de un reporte: creación, asignación, cambio de estado, acción correctiva, cancelación | `reportes`, `usuarios`, `estados` |

Reglas del modelo:

- **Nada se borra.** Un reporte se cancela (`cancelado_reporte = 1`), y el historial y las evidencias solo crecen. Todas las llaves foráneas son `ON DELETE RESTRICT`.
- **El historial se escribe en la misma transacción** que el cambio que registra: o se guardan los dos o ninguno (ver `docs/db-functions.md`).
- **La BD rechaza datos inconsistentes por sí misma** con 13 `CHECK`: coordenadas en rango y juntas, textos sin vacíos, razón de cancelación solo si está cancelado, los estados correctos en cada tipo de movimiento, etc. El detalle y lo que revisa la API en su lugar está en `docs/restricciones-bd.md`.
