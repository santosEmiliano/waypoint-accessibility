# Autenticación y roles

Cómo funcionan el token, las sesiones y los permisos en el backend (issues #22 y #23). El contrato con la app está en `docs/api.md`; aquí está lo que ese documento deja a cargo del backend.

Todo vive en `backend/src/auth/`, en TypeScript. El servidor se corre con `tsx` (`npm run dev` y `npm start` ya lo usan), así que un archivo `.js` puede importar estos módulos sin compilar nada.

## Contraseñas (`auth/contrasenas.ts`)

- Se guardan solo con **bcrypt de 12 rondas**; la BD nunca ve la contraseña real.
- `validarContrasena(texto)` devuelve el mensaje de error o `null`. Pide **mínimo 8 caracteres** y **máximo 72 bytes** (bcrypt ignora lo que pase de 72, y los acentos cuentan más de un byte).
- `hashearContrasena(texto)` y `verificarContrasena(texto, hash)`.
- `HASH_FALSO`: en el login, si el correo no existe, compara contra este hash para que la respuesta tarde lo mismo y no revele qué correos están registrados.

## Token y sesión (`auth/token.ts`, `auth/sesiones.ts`)

- El token es un **JWT HS256** firmado con `JWT_SECRET` (mínimo 16 caracteres; si falta o es corto, el servidor falla en vez de firmar con un secreto débil). Vence a las `JWT_EXPIRES_IN` (8 h por defecto).
- Solo lleva el id del usuario (`sub`) y el id de la sesión (`jti`). **El rol no va en el token**: se lee de la BD en cada petición, así que un cambio de rol surte efecto al instante.
- Cada token tiene una **sesión en Redis** (`sesion:<jti>`) que Redis borra sola cuando el token vence. Un token solo sirve mientras su sesión exista: al cerrar sesión se borra y el token responde `401` aunque no haya vencido.

| Función | Para qué |
|---|---|
| `emitirToken(almacen, idUsuario)` | Crea el token y su sesión. Se usa en `POST /auth/registro` y `POST /auth/login` |
| `cerrarSesion(almacen, token)` | Borra la sesión. Se usa en `POST /auth/logout`. Si el token ya no era válido no hace nada, y el logout igual responde `204` |
| `leerToken(token)` | Devuelve `{ idUsuario, idSesion }` o `null` si es inválido, alterado o vencido |

El `almacen` se obtiene así:

```ts
import { obtenerRedis } from "../redis";
import { crearAlmacenRedis } from "../auth/sesiones";

const almacen = crearAlmacenRedis(await obtenerRedis());
```

## Proteger rutas (`auth/middleware.ts`)

```js
import { autenticar, requerirRol, soloOperador } from "./auth/middleware.ts";

app.get("/auth/usuario", autenticar, (req, res) => { /* req.usuario */ });
app.get("/admin/reportes", autenticar, soloOperador, (req, res) => { /* ... */ });
```

- `autenticar` lee `Authorization: Bearer <token>`. Responde `401 NO_AUTENTICADO` si falta, es inválido, venció, su sesión se cerró o el usuario ya no existe. Si todo va bien deja **`req.usuario`** (sin hash de contraseña) y **`req.token`** (para el logout).
- `requerirRol("operador")` va **después** de `autenticar`. Responde `403 SIN_PERMISO` si el rol no está permitido. `soloOperador` es un atajo. Si se pone sin `autenticar`, responde `401` y no deja pasar.
- En las rutas de un usuario (por ejemplo "mis reportes") el id sale de `req.usuario.idUsuario`, nunca de lo que mande la app.

## Variables de entorno

| Variable | Para qué |
|---|---|
| `JWT_SECRET` | Firma de los tokens. Cámbialo del valor de ejemplo |
| `JWT_EXPIRES_IN` | Vigencia del token (`8h`) |
| `REDIS_URL` | Conexión a Redis, donde viven las sesiones |

Redis debe estar levantado (`docker compose up -d`) para cualquier ruta protegida.

## Qué falta (lo hace la API, #24)

- Las rutas `/auth/*`: validar el cuerpo, llamar a `crearUsuario`, `buscarUsuarioPorCorreo`, `actualizarUsuario` (ver `docs/db-functions.md`) y a `emitirToken` / `cerrarSesion`.
- El límite de intentos del login (`429 DEMASIADOS_INTENTOS`).
- Quitar el hash antes de responder si se usa `buscarUsuarioPorCorreo`, que es la única función que lo devuelve.
