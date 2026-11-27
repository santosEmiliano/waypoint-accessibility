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

### `listarReportes({ idUsuario?, idEstado?, idCategoria?, texto?, cancelados? })`

Todos los filtros son opcionales y **se combinan** (se cumplen todos a la vez).

| Filtro | Efecto |
|---|---|
| `idUsuario` | Solo los reportes de ese usuario. Sin él devuelve los de todos: la API lo manda cuando quien consulta es un `usuario`, y no lo manda para el `operador` |
| `idEstado` | Solo los de ese estado |
| `idCategoria` | Solo los de esa categoría |
| `texto` | Los que lo tengan en el título, la descripción o la ubicación. No distingue mayúsculas ni acentos (lo decide la colación de MySQL). Un texto vacío no filtra. `%`, `_` y `\` se buscan como texto, no como comodines (`escaparLike`) |
| `cancelados` | Con `true` devuelve **solo** los cancelados. Sin él, los cancelados no aparecen |

- **Retorna:** `Reporte[]`, los más recientes primero. Sin resultados devuelve `[]`.
- `armarFiltros(filtros)` es la parte que arma el `WHERE`; está exportada para probarla sola.

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

### `listarHistorial(idReporte)`

- **Retorna:** las filas del reporte de la más antigua a la más reciente, cada una con `tipoHistorial`, `descripcionHistorial`, `creacionHistorial`, `estadoAnterior`, `estadoNuevo` y `usuario` (`{ idUsuario, nombreUsuario }`).
- No revisa de quién es el reporte: la API primero lo consulta con `obtenerReporte` (que sí lo revisa) y responde `404` si no es suyo.

## Pruebas

- `backend/tests/reportes.test.ts`: lógica de las funciones con Prisma simulado (no necesita la BD).
- `backend/tests/historial.integracion.test.ts`: contra la **BD real**, incluida la prueba de que si falla el historial el estado no cambia. Necesita `docker compose up -d` con la BD migrada y sembrada; si no está disponible, se salta sola.
