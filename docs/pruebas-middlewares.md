# Pruebas de middlewares y errores de BD

Casos probados del issue #50: autenticación, roles, validación, sanitización, y qué pasa si la BD o Redis no responden.

Todo corre con `npm test` desde `backend/`. Las pruebas de integración necesitan la BD levantada; si no está, se saltan solas.

## Archivos

| Archivo | Qué prueba |
|---|---|
| `tests/auth.test.ts` | Token, sesiones, `autenticar` y `requerirRol` por separado |
| `tests/validacion.test.ts` | Las reglas y los esquemas de cada ruta |
| `tests/sanitizacion.test.ts` | La limpieza de textos y el middleware `sanitizar` |
| `tests/sanitizacion.integracion.test.ts` | Inyección SQL contra la BD real |
| `tests/cadena-middlewares.test.ts` | Los middlewares juntos, en el orden de las rutas, y Redis o la BD caídos |
| `tests/bd-caida.test.ts` | Cuánto tarda en fallar una consulta si la BD no responde |
| `tests/restricciones.integracion.test.ts` | Que la BD rechace datos inconsistentes (ver `docs/restricciones-bd.md`) |

## Orden de los middlewares

Las rutas van así: `express.json` → `sanitizar` → `autenticar` → `requerirRol` → `validar` → controlador.

| Caso | Respuesta |
|---|---|
| Sin token y con el cuerpo mal | `401 NO_AUTENTICADO`. Primero se pide sesión, para no revelar qué valida cada ruta |
| Usuario en una ruta de operador, con el cuerpo mal | `403 SIN_PERMISO` |
| Operador con el cuerpo mal | `400 VALIDACION` con todos los campos malos en `campos` (también el `:id` de la URL) |
| JSON con más de 5 niveles, sin token | `400 VALIDACION`. Lo corta `sanitizar`, que va antes de las rutas |
| Texto con HTML, espacios o caracteres invisibles | El controlador lo recibe limpio y recortado |
| Campos que no están en el esquema (`id_estado`, `id_usuario`) | Se descartan: un usuario no puede elegir el estado ni el dueño de su reporte |
| `:id` válido | Llega convertido a número en `req.validado.params` |

## Autenticación y roles

Ya cubiertos en `tests/auth.test.ts`:
- **Token que no sirve:** se rechazan el token ausente, mal formado, vencido, firmado con otro secreto, con algoritmo `none`, el de una sesión cerrada (logout) y el de un usuario que ya no existe.
- **Sesiones:** dos sesiones del mismo usuario son independientes; cerrar una no cierra la otra.
- **Roles:** el rol se lee de la BD en cada petición. Si a alguien le bajan el rango, pierde el acceso sin esperar a que venza el token.

## Si la BD o Redis no responden

| Caso | Respuesta |
|---|---|
| Redis caído al revisar la sesión | `500 ERROR_INTERNO`, **no** `401`: no se cierra la sesión de nadie por una caída |
| BD caída al leer el usuario | `500 ERROR_INTERNO`. El detalle (`ECONNREFUSED`) va a la consola del servidor, no a la respuesta |
| La BD vuelve | La misma sesión sigue funcionando |
| Una función de `src/db` con la BD caída | Lanza el error. Si devolviera `null`, `autenticar` respondería `401` como si el usuario no existiera |
| Tiempo hasta que falla una consulta | **Unos 6 s** (antes, unos 20 s) |

**Lo que se encontró:** con la configuración por defecto del adaptador, si la BD se cae cada petición se queda esperando unos 20 s antes de fallar, porque espera 10 s por una conexión y Prisma reintenta una vez. No pasaba solo al arrancar: le pasaba a cada petición. Se bajó `acquireTimeout` a 3 s en `backend/src/db/prisma.ts`, y ahora falla en unos 6 s. Con 5 conexiones y consultas cortas, 3 s sobran para la carga normal.

## Errores de la BD que se traducen

| Error de Prisma | Función | Se convierte en |
|---|---|---|
| `P2002` (valor repetido) en el correo | `crearUsuario` | `CorreoDuplicadoError` (la API responde `409 CORREO_REGISTRADO`) |
| `P2002` en la ruta de una evidencia | `guardarEvidencia` | `RutaDuplicadaError` |
| `P2003` (llave foránea) | `crearReporte`, `guardarEvidencia` | Se lanza tal cual (por ejemplo, una categoría que no existe) |
| Violación de un `CHECK` | Cualquiera | Se lanza tal cual. La API valida antes, así que solo pasa si alguien se la salta |
