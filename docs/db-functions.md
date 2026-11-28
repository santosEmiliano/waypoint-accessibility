# Funciones de acceso a datos

Funciones que el backend usa para hablar con la BD. Viven en `backend/src/db/` y usan el cliente de Prisma de `backend/src/db/prisma.ts`. Los controladores de la API no deben usar Prisma directamente: llaman a estas funciones.

Todas son `async` y los nombres de campos van en camelCase, como en `schema.prisma`.

## Usuarios

Archivo: `backend/src/db/usuarios.ts`.

**Tipos que devuelven**

- `UsuarioPublico`: `{ idUsuario, nombreUsuario, correoUsuario, creacionUsuario, rol: { idRol, nombreRol } }`. **Nunca incluye el hash de la contraseña.**
- `UsuarioConHash`: lo mismo más `contrasenaUsuario` (el hash de bcrypt). Solo lo devuelve `buscarUsuarioPorCorreo`.

### `crearUsuario({ nombre, correo, contrasenaHash })`

Crea una cuenta con rol `usuario`.

| Parámetro | Tipo | Notas |
|---|---|---|
| `nombre` | `string` | Se le quitan los espacios de los extremos |
| `correo` | `string` | Se guarda en minúsculas y sin espacios |
| `contrasenaHash` | `string` | El hash de bcrypt, ya calculado (ver `auth/contrasenas.ts`). Nunca la contraseña real |

- **Retorna:** `UsuarioPublico`.
- **Lanza:** `CorreoDuplicadoError` si ya existe una cuenta con ese correo. La API lo convierte en `409`.
- El rol siempre es `usuario`: los operadores salen de la semilla.

### `buscarUsuarioPorCorreo(correo)`

- **Parámetro:** `correo` (`string`); se normaliza igual que al crear, así que no distingue mayúsculas.
- **Retorna:** `UsuarioConHash`, o `null` si el correo no existe.
- Es la única función que devuelve el hash: es para que el login lo compare. Hay que quitarlo antes de responder.

### `buscarUsuarioPorId(idUsuario)`

- **Parámetro:** `idUsuario` (`number`).
- **Retorna:** `UsuarioPublico`, o `null` si el id no existe.

### `actualizarUsuario(idUsuario, { nombre?, contrasenaHash? })`

Para `PUT /auth/usuario`. Cambia el nombre, la contraseña o ambos. No toca el correo ni el rol.

| Parámetro | Tipo | Notas |
|---|---|---|
| `idUsuario` | `number` | El usuario de la sesión |
| `nombre` | `string` (opcional) | Se le quitan los espacios de los extremos |
| `contrasenaHash` | `string` (opcional) | Hash ya calculado |

- **Retorna:** `UsuarioPublico` actualizado, o `null` si el id no existe.
- Si no se manda ningún cambio, no escribe nada y devuelve el usuario tal como está.
- Verificar la contraseña actual (`422 CONTRASENA_INCORRECTA`) es trabajo de la API, antes de llamar a esta función.

### Correo único

El correo es único en la BD (índice `correo_usuario_UNIQUE`), así que dos cuentas no pueden compartirlo aunque dos peticiones lleguen al mismo tiempo. Además se normaliza a minúsculas antes de guardar.

## Categorías y estados

Archivo: `backend/src/db/categorias.ts`. Son catálogos de solo lectura: sus filas vienen de la semilla y no hay funciones para modificarlas.

### `listarCategorias()`

- **Retorna:** `{ idCategoria, nombreCategoria }[]`, en orden alfabético.
- Para `GET /categorias`.

### `listarEstados()`

- **Retorna:** `{ idEstado, nombreEstado, ordenEstado }[]`, del 1 al 4 según `ordenEstado` (nunca según el id).
- Para `GET /estados`.

## Reportes

Archivo: `backend/src/db/reportes.ts`.

**Qué devuelven.** Todas devuelven un `Reporte`:

```ts
{
  idReporte, tituloReporte, descripcionReporte, ubicacionReporte,
  latitudReporte, longitudReporte,            // Decimal de Prisma o null: la API los pasa con Number()
  canceladoReporte, razonCancelacionReporte,
  creacionReporte, actualizacionReporte,
  categoria: { idCategoria, nombreCategoria },
  estado: { idEstado, nombreEstado, ordenEstado },
  usuario: { idUsuario, nombreUsuario },      // el creador
  operador: { idUsuario, nombreUsuario } | null,
}
```

De las personas solo se devuelve el id y el nombre, nunca el correo. La API cambia los nombres a `snake_case` al responder (ver `docs/api.md`).

**Transacciones.** Las funciones que cambian un reporte (`crearReporte`, `cancelarReporte`, `asignarReporte` y `cambiarEstadoReporte`) escriben el historial **en la misma transacción**: o se guardan el cambio y su historial, o no se guarda nada.

### `crearReporte({ idUsuario, titulo, descripcion, idCategoria, ubicacion, latitud?, longitud? })`

- Nace en el estado con `ordenEstado = 1` (Reportado), sin operador, y escribe el historial `creacion`.
- Texto con los espacios de los extremos recortados.
- **Retorna:** `Reporte`.
- **Lanza:** `Error` si viene solo la latitud o solo la longitud (van juntas), y el error de la BD si la categoría o el usuario no existen (llave foránea). No deja nada guardado.
- Las validaciones de largo y de rango (`docs/api.md`) son de la API.

### `listarReportes({ idUsuario?, idEstado?, idCategoria?, texto?, cancelados? }, { limite?, desde?, orden? })`

Todos los filtros son opcionales y **se combinan** (se cumplen todos a la vez).

| Filtro | Efecto |
|---|---|
| `idUsuario` | Solo los reportes de ese usuario. Sin él devuelve los de todos: la API lo manda cuando quien consulta es un `usuario`, y no lo manda para el `operador` |
| `idEstado` | Solo los de ese estado |
| `idCategoria` | Solo los de esa categoría |
| `texto` | Los que lo tengan en el título, la descripción o la ubicación. No distingue mayúsculas ni acentos (lo decide la colación de MySQL). Un texto vacío no filtra. `%`, `_` y `\` se buscan como texto, no como comodines (`escaparLike`) |
| `cancelados` | Con `true` devuelve **solo** los cancelados. Sin él, los cancelados no aparecen |

El segundo argumento es la página, también opcional:

| Campo | Efecto |
|---|---|
| `limite` | Cuántos devolver (`take`). Sin él devuelve todos, como antes |
| `desde` | Cuántos saltarse (`skip`). La página `n` (empezando en 0) es `desde = n * limite` |
| `orden` | `"creacion"` (por defecto): los creados más recientemente primero. `"actualizacion"`: los que cambiaron más recientemente primero |

- **Retorna:** `Reporte[]`, del más nuevo al más viejo según `orden`. Sin resultados (o con `desde` más allá del final) devuelve `[]`.
- **Desempate por id:** las fechas se guardan al segundo, así que dos reportes pueden tener la misma. Con el mismo segundo va primero el id más alto. Sin ese desempate, el orden entre ellos podría cambiar de una consulta a otra y un reporte se repetiría o se saltaría al pasar de página.
- `armarFiltros(filtros)` es la parte que arma el `WHERE`; está exportada para probarla sola.

### `contarReportesPorEstado({ idUsuario?, idCategoria?, texto? })`

Para el resumen de la pantalla principal (`GET /reportes/resumen`).

- Cuenta los reportes **no cancelados** de cada estado, con los mismos filtros que `listarReportes`: con `idUsuario` solo los de ese usuario (la API lo manda para un `usuario` y no para el `operador`).
- No acepta `idEstado` ni `cancelados`: el resumen es justo el conteo por estado de los que siguen activos.
- El conteo es una sola consulta (`groupBy` por `id_estado`). Aparte se lee el catálogo de estados para devolver también los que tienen 0.
- **Retorna:** `[{ idEstado, total }]` con **los 4 estados**, en su orden (Reportado → Resuelto), aunque alguno esté en 0. La API lo responde como `[{ "id_estado": 1, "total": 2 }, ...]`.

### `obtenerReporte(idReporte, { idUsuario? })`

- Detalle, cancelado o no.
- Con `idUsuario` solo lo devuelve si el reporte es suyo. El de otro usuario responde `null`, igual que uno que no existe, para que la API responda `404` sin revelar que existe.
- Sin `idUsuario` (el operador) busca entre todos.
- **Retorna:** `Reporte`, o `null`.

### `cancelarReporte({ idReporte, idUsuario, razon? })`

Solo el dueño, solo en Reportado y solo si no estaba cancelado. No se borra: queda `canceladoReporte = true`, con la razón si se mandó, y se escribe el historial `cancelacion`. Las tres condiciones van en el `WHERE` del `UPDATE`, así que si un operador lo mueve de estado justo antes, no se cancela.

| `resultado` | Cuándo | La API responde |
|---|---|---|
| `"ok"` (con `reporte`) | Se canceló | `200` |
| `"no_encontrado"` | No existe, o es de otro usuario | `404 NO_ENCONTRADO` |
| `"no_editable"` | Es suyo, pero ya no está en Reportado o ya estaba cancelado | `422 REPORTE_NO_EDITABLE` |

### `asignarReporte({ idReporte, idOperador })`

El operador toma el reporte, y solo si nadie lo tenía, no está cancelado y no está Resuelto. Escribe el historial `asignacion`.

- **Retorna:** `{ actualizadas, reporte }`. `actualizadas` es `1` si lo tomó y `0` si no pudo (reporte con `reporte: null`).
- Si es `0`, la API consulta con `obtenerReporte` para saber el motivo: otro operador (`409 REPORTE_YA_ASIGNADO`), cancelado o Resuelto (`422`), o el mismo operador que ya lo tenía (`200` sin cambios).
- Funciona aunque dos operadores lo intenten a la vez: la BD ejecuta el `UPDATE` de forma atómica y solo uno afecta la fila.

### `cambiarEstadoReporte({ idReporte, idUsuario, idEstadoActual, idEstadoNuevo, descripcion? })`

Cambia el estado y escribe el historial `cambio_estado` (con el estado anterior, el nuevo y el comentario).

- `idUsuario` es quien hace el cambio, para el historial.
- La condición `id_estado = idEstadoActual` va en el `WHERE`: si alguien ya lo había movido, no se pisa su cambio.
- **Retorna:** `{ actualizadas, reporte }`. `actualizadas` es `0` si el estado ya no era `idEstadoActual` (la API responde `409 ESTADO_DESACTUALIZADO`).
- **No valida** que la transición sea la siguiente (`ordenEstado + 1`), que quien llama sea el operador asignado, ni que exista la foto de atención para Resuelto: eso lo valida la API antes de llamarla (`docs/api.md`).
- **Si el historial no se puede escribir, lanza el error y el estado queda como estaba.**

## Historial

Archivo: `backend/src/db/historial.ts`. Es de solo inserción: no hay funciones para editar ni borrar filas.

### `registrarHistorial(tx, { idReporte, idUsuario, tipo, idEstadoAnterior?, idEstadoNuevo?, descripcion? })`

Escribe una fila usando **la transacción de quien llama**. Para eso recibe `tx` y no usa el cliente global: si el cambio y su historial no comparten transacción, uno puede guardarse sin el otro.

```ts
await prisma.$transaction(async (tx) => {
  await tx.reporte.update(/* el cambio */);
  await registrarHistorial(tx, { idReporte, idUsuario, tipo: "edicion" }); // si falla, se deshace el cambio
});
```

`tipo` es uno de: `creacion`, `edicion`, `asignacion`, `cambio_estado`, `accion_correctiva`, `cancelacion`. Qué campos lleva cada tipo está en `docs/api.md`.

Las funciones de reportes ya la usan; hay que llamarla directamente solo para lo que todavía no tiene función propia: `edicion` (`PUT /reportes/:id`, #30) y `accion_correctiva` (`POST /reportes/:id/acciones`, #38).

### `consultarHistorial(idReporte, { idUsuario? })`

Para `GET /reportes/:id/historial` (#46). Revisa que quien consulta pueda ver el reporte y devuelve su línea de tiempo.

- Con `idUsuario` (quien consulta es un `usuario`) solo responde si el reporte es suyo. El de otro usuario devuelve `null`, igual que uno que no existe, para que la API responda `404` sin revelar que existe.
- Sin `idUsuario` (el operador) busca entre todos.
- **Retorna:** `FilaHistorial[]` (lo mismo que `listarHistorial`), o `null`.

```js
const historial = await consultarHistorial(id, { idUsuario: esOperador ? undefined : req.usuario.idUsuario });
if (!historial) return responder404();
```

### `listarHistorial(idReporte)`

- **Retorna:** `FilaHistorial[]`, de la más antigua a la más reciente. Cada fila trae `idHistorial`, `tipoHistorial`, `descripcionHistorial`, `creacionHistorial`, `estadoAnterior` y `estadoNuevo` (`{ idEstado, nombreEstado, ordenEstado }` o `null`) y `usuario`, el responsable del movimiento (`{ idUsuario, nombreUsuario }`, sin correo).
- La fecha se guarda sin milisegundos, así que dos movimientos del mismo segundo (crear y asignar, por ejemplo) se ordenan por su id, que es el orden en que se escribieron.
- No revisa de quién es el reporte. Para la API conviene `consultarHistorial`, que sí lo revisa.

## Evidencias

Archivo: `backend/src/db/evidencias.ts`. En la BD solo se guarda la ruta del archivo y sus datos, nunca la imagen. Es de solo inserción: una foto subida no se borra (`docs/api.md`).

**Qué devuelven.** Una `Evidencia`:

```ts
{
  idEvidencia, tipoEvidencia,               // "reporte" o "atencion"
  rutaEvidencia,                            // por ejemplo "/uploads/<uuid>.jpg"
  creacionEvidencia,
  usuario: { idUsuario, nombreUsuario },    // quien subió la foto
}
```

### `guardarEvidencia({ idReporte, idUsuario, tipo, ruta })`

Guarda los datos de una foto que la API ya escribió en `uploads/` (#45).

| Parámetro | Tipo | Notas |
|---|---|---|
| `idReporte` | `number` | El reporte al que pertenece |
| `idUsuario` | `number` | Quien la subió |
| `tipo` | `"reporte"` o `"atencion"` | Lo decide la API según el rol, la app no lo manda |
| `ruta` | `string` | La que la API va a responder en `ruta_evidencia`. Se recorta; de 1 a 500 caracteres |

- **Retorna:** `Evidencia`.
- **Lanza:**
  - `RutaDuplicadaError` si ya hay una evidencia con esa ruta (es `UNIQUE`; con nombres UUID no debería pasar).
  - El error de la BD si el reporte o el usuario no existen (llave foránea).
  - `Error` si la ruta está vacía o pasa de 500 caracteres, o si el tipo no es `reporte` ni `atencion`. No toca la BD.
- **No valida** quién puede subir ni en qué estado (creador en Reportado → `reporte`; operador asignado en En análisis o En atención → `atencion`). Eso lo revisa la API antes de escribir el archivo (`docs/api.md`).

### `listarEvidencias(idReporte, { idUsuario? })`

Para `GET /reportes/:id/evidencias` (#45).

- Las fotos de los dos tipos, de la más antigua a la más reciente (las del mismo segundo, por id).
- Con `idUsuario` solo responde si el reporte es suyo; si es de otro o no existe devuelve `null` (la API responde `404`). Sin `idUsuario` (el operador) busca entre todos.
- **Retorna:** `Evidencia[]` (`[]` si no tiene fotos), o `null`.

### `contarEvidenciasPorTipo(idReporte)`

- **Retorna:** `{ reporte, atencion }`, cuántas fotos de cada tipo tiene. Siempre trae los dos (`0` si no hay).
- Es para la regla del sistema: para pasar a Resuelto hace falta al menos una foto de tipo `atencion`. La API la usa antes de llamar a `cambiarEstadoReporte`:

```js
if (estadoNuevo.ordenEstado === ORDEN_ESTADO_FINAL) {
  const { atencion } = await contarEvidenciasPorTipo(id);
  if (atencion === 0) return responder422("FALTA_EVIDENCIA_ATENCION");
}
```

- No hay carrera entre contar y cambiar el estado: las fotos nunca se borran, así que el conteo solo puede subir.

## Pruebas

- `backend/tests/reportes.test.ts` y `backend/tests/evidencias.test.ts`: lógica de las funciones con Prisma simulado (no necesitan la BD).
- `backend/tests/historial.integracion.test.ts`: contra la **BD real**, incluida la prueba de que si falla el historial el estado no cambia, y la de `consultarHistorial` (orden, responsable y quién puede verlo).
- `backend/tests/evidencias.integracion.test.ts`: contra la **BD real**: ruta repetida, reporte que no existe, conteo por tipo, orden y quién puede ver las fotos.
- `backend/tests/paginacion.integracion.test.ts`: contra la **BD real**: que las páginas juntas den la lista completa sin repetir ni saltar (con reportes del mismo segundo), el orden por actualización y el resumen por estado (los 4 estados, sin cancelados, con filtros).

Las de BD real necesitan `docker compose up -d` con la BD migrada y sembrada; si no está disponible, se saltan solas.
