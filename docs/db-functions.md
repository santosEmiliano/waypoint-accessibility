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
