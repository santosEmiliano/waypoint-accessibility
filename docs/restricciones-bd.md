# Restricciones de la BD

Revisión del issue #51: qué datos inconsistentes rechaza la BD por sí misma, aunque alguien se salte la API, y cuáles reglas quedan en la API o en las funciones de `backend/src/db`, y por qué.

Las restricciones viven en dos migraciones de `backend/prisma/migrations/`:
- `esquema_inicial`: tablas, llaves foráneas, `UNIQUE` y los primeros 3 `CHECK`.
- `revision_restricciones`: los 10 `CHECK` de esta revisión.

Se prueban contra la BD real en `backend/tests/restricciones.integracion.test.ts`.

## Llaves foráneas

Son 11 y todas son `ON DELETE RESTRICT`: no se puede borrar algo que otra tabla usa. Por ejemplo, no se borra un usuario con reportes ni un estado que ya aparece en el historial. Cada llave tiene su índice.

Todas son `ON UPDATE CASCADE`, menos `historial.id_estado_anterior` e `historial.id_estado_nuevo`, que pasaron a `RESTRICT`. MySQL no deja usar en un `CHECK` una columna con acción en cascada, y el `CHECK` del historial las necesita. En la práctica no cambia nada: el id de un estado nunca se modifica.

## Valores únicos

| Columna | Para qué |
|---|---|
| `usuarios.correo_usuario` | Un correo, una cuenta. La comparación no distingue mayúsculas (`ANA@x.com` = `ana@x.com`) por la collation `utf8mb4_unicode_ci` |
| `evidencias.ruta_evidencia` | Dos evidencias no pueden apuntar al mismo archivo |
| `roles.nombre_rol`, `categorias.nombre_categoria`, `estados.nombre_estado` | Catálogos sin repetidos |
| `estados.orden_estado` | Un solo estado por posición (1 a 4) |

## CHECK

| Restricción | Rechaza |
|---|---|
| `chk_estados_orden` | Un estado fuera de las posiciones 1 a 4 |
| `chk_reportes_coordenadas` | Solo la latitud o solo la longitud: van las dos o ninguna |
| `chk_reportes_latitud` | Latitud fuera de −90 a 90 (la columna `DECIMAL(9,6)` aceptaría ±999) |
| `chk_reportes_longitud` | Longitud fuera de −180 a 180 |
| `chk_reportes_titulo`, `chk_reportes_descripcion`, `chk_reportes_ubicacion` | Textos vacíos o con solo espacios |
| `chk_reportes_razon_cancelacion` | Una razón de cancelación en un reporte que no está cancelado |
| `chk_usuarios_nombre` | Nombre vacío o con solo espacios |
| `chk_usuarios_correo` | Un correo sin algo antes y después de la arroba. El formato completo lo valida la API |
| `chk_evidencias_ruta` | Ruta vacía |
| `chk_historial_estados` | Un movimiento con estados que no le tocan: `creacion` lleva solo el nuevo; `cambio_estado` lleva los dos y distintos; los demás tipos no llevan ninguno |
| `chk_historial_accion_descripcion` | Una acción correctiva sin descripción |

Los `CHECK` se revisan al insertar y al actualizar. MySQL responde con el nombre de la restricción, por ejemplo `Check constraint 'chk_reportes_latitud' is violated`, y Prisma lo pasa en el mensaje del error.

## Lo que la BD no revisa (y quién lo hace)

Un `CHECK` solo puede ver la fila que se guarda: no puede consultar otra tabla ni otras filas. La otra opción serían triggers, pero complican las migraciones: con el binlog activo, MySQL pide permisos extra al usuario que migra. Por eso estas reglas viven en el código:

| Regla | Dónde se revisa |
|---|---|
| El operador asignado (`reportes.id_operador`) tiene rol `operador` | La API: la ruta de asignar lleva `soloOperador` y le pasa a `asignarReporte` el usuario de la sesión |
| El estado avanza un paso a la vez (nuevo = actual + 1) | La API, antes de llamar a `cambiarEstadoReporte` (`docs/api.md`) |
| No se pasa a Resuelto sin una foto de `atencion` | La API, con `contarEvidenciasPorTipo` |
| Solo el dueño cancela, y solo en Reportado | `cancelarReporte` (las condiciones van en el `WHERE` del `UPDATE`) |
| Un reporte cancelado no cambia de estado ni se asigna | `cambiarEstadoReporte` y `asignarReporte` (`cancelado_reporte = false` en el `WHERE`) |
| El historial y las evidencias no se modifican ni se borran | No hay funciones que lo hagan. Las pruebas sí borran sus datos al terminar |
| Un solo movimiento `creacion` por reporte | `crearReporte` lo escribe en la misma transacción que el reporte |
| Los límites de largo (2000 en descripciones y razones) | La API. La columna `TEXT` admite más |

## Índices

Cada llave foránea y cada valor único tiene su índice, y no hay índices repetidos. Se revisaron las consultas de `backend/src/db`:

| Consulta | Índice que usa |
|---|---|
| Login: usuario por correo | `correo_usuario_UNIQUE` |
| Listar reportes por usuario, estado o categoría | `fk_reportes_usuario_idx`, `fk_reportes_estado_idx`, `fk_reportes_categoria_idx` |
| Historial de un reporte | `fk_historial_reporte_idx` |
| Evidencias de un reporte y su conteo por tipo | `fk_evidencias_reporte_idx` |
| Estado inicial y final por orden | `orden_estado_UNIQUE` |

No se agregaron índices.
- **Orden de la lista:** ordenar por fecha (`creacion_reporte`) se hace sin índice, pero con los cientos de reportes de la demo no se nota. Si hubiera miles, el siguiente paso sería un índice compuesto `(id_usuario, creacion_reporte)`.
- **Búsqueda por texto:** `LIKE '%texto%'` no puede usar un índice normal en ningún caso.

## Aplicar los cambios

En desarrollo: `npm run db:migrate` desde `backend/`. En el servidor: `npm run db:deploy` por el túnel (ver `docs/despliegue-bd.md`).

Si una BD ya tiene datos que no cumplen un `CHECK` nuevo, la migración falla y no aplica nada de esa restricción. Antes de migrar se pueden buscar con consultas como `SELECT * FROM reportes WHERE latitud_reporte NOT BETWEEN -90 AND 90`.
