# Validación y sanitización

Cómo revisa y limpia el backend lo que manda la app (issues #34 y #35). Las reglas de cada campo están en `docs/api.md`; aquí está cómo se aplican.

Todo vive en `backend/src/middlewares/`, en TypeScript:

| Archivo | Qué hace |
|---|---|
| `sanitizacion.ts` | Limpia el texto de entrada. Su middleware `sanitizar` ya está puesto en `app.js` para todas las rutas |
| `validacion.ts` | El middleware `validar(esquema)` y las reglas (`texto`, `entero`, `correo`...) |
| `esquemas.ts` | Qué acepta cada ruta del contrato, ya armado |

## El orden de una petición

```
express.json()  →  sanitizar  →  autenticar  →  validar(esquema)  →  controlador
   lee el JSON      limpia el     revisa el       revisa los campos
                    cuerpo        token           de la ruta
```

`sanitizar` es global (está en `app.js`). `validar` se pone en cada ruta, con su esquema.

## Validación (`validar`)

```js
import { validar } from "./middlewares/validacion.ts";
import { esquemas } from "./middlewares/esquemas.ts";

router.post("/reportes", autenticar, validar(esquemas.crearReporte), (req, res) => {
  const { titulo_reporte, id_categoria } = req.body; // ya validado y limpio
});

router.get("/reportes/:id", autenticar, validar(esquemas.idReporte), (req, res) => {
  const { id } = req.validado.params; // un número, no el texto "7"
});
```

Qué hace:

- Revisa el cuerpo, los parámetros de la URL y la query, según lo que traiga el esquema.
- **Junta todos los errores** y responde una sola vez con el formato del contrato:

  ```json
  {
    "error": {
      "codigo": "VALIDACION",
      "mensaje": "Hay campos inválidos",
      "campos": { "correo_usuario": "Formato inválido", "titulo_reporte": "Es obligatorio" }
    }
  }
  ```

- Los mensajes de `campos` solo describen el formato ("Es obligatorio", "Formato inválido", "Máximo 200 caracteres"), nunca algo de la BD.
- Si todo está bien, deja en **`req.validado`** (`{ body, params, query }`) **solo los campos del esquema**, ya limpios y convertidos. También reemplaza `req.body` por la versión validada.
- **Lo que no está en el esquema se descarta.** Si alguien manda `"nombre_rol": "operador"` en el registro, no llega al controlador.
- `req.query` no se reemplaza (en Express 5 no se puede): los filtros se leen de `req.validado.query`.

### Esquemas que ya existen (`esquemas.ts`)

| Esquema | Ruta | Qué revisa |
|---|---|---|
| `registro` | `POST /auth/registro` | Nombre (1–100), correo (formato, hasta 200), contraseña (mínimo 8, máximo 72 bytes) |
| `login` | `POST /auth/login` | Correo y contraseña. A la contraseña solo le pide que venga, sin el mínimo, para no dejar fuera a una cuenta vieja si la regla cambia |
| `actualizarUsuario` | `PUT /auth/usuario` | Nombre opcional; contraseña actual y nueva van juntas; al menos un cambio |
| `crearReporte` | `POST /reportes` | Título (1–200), descripción (1–2000), categoría, ubicación (1–255), coordenadas opcionales y juntas |
| `editarReporte` | `PUT /reportes/:id` | El id y el mismo cuerpo que al crear |
| `listarReportes` | `GET /reportes` | `id_estado`, `id_categoria`, `q` (hasta 100) y `cancelados` (`true` o `false`), todos opcionales |
| `idReporte` | `GET /reportes/:id`, historial, evidencias, asignar | Solo el id |
| `cancelarReporte` | `PATCH /reportes/:id/cancelar` | La razón, opcional (hasta 2000). Sin razón queda en `null` |
| `cambiarEstado` | `PATCH /reportes/:id/estado` | `id_estado` y el comentario opcional (hasta 2000) |
| `accionCorrectiva` | `POST /reportes/:id/acciones` | La descripción, obligatoria (1–2000) |

### Las reglas

| Regla | Qué acepta | Qué devuelve |
|---|---|---|
| `texto({ max, min?, multilinea? })` | Un texto. Lo limpia (ver sanitización) y le quita los espacios de los extremos | El texto limpio. Con `multilinea: false` (títulos) los saltos de línea se vuelven espacios |
| `entero({ max, min? })` | `7` o `"7"` (los parámetros y la query siempre llegan como texto) | Un número. `max` es el tope de la columna, para que un id enorme dé `400` y no un `500` de la BD |
| `decimal({ min, max, decimales })` | Un número (no un texto) dentro del rango y con máximo esos decimales | El número |
| `booleano()` | `true`, `false`, `"true"` o `"false"` | `true` o `false` |
| `correo({ max })` | Un correo con formato `algo@dominio.ext` | En minúsculas y sin espacios |
| `contrasenaNueva()` | Las reglas de `auth/contrasenas.ts` | La contraseña tal cual, sin limpiar ni recortar |
| `contrasenaGuardada()` | Cualquier texto no vacío | La contraseña tal cual |
| `opcional(regla)` | Si no viene (o viene vacío o con solo espacios), el campo se omite | |
| `nulable(regla)` | Igual, pero el campo queda en `null` (para columnas que aceptan NULL) | |

Detalles:

- Los largos se cuentan **como MySQL**: un emoji cuenta como 1 carácter (en JavaScript `"😡".length` es 2).
- Las reglas entre varios campos (latitud y longitud juntas, contraseña actual y nueva juntas) van en `cruzadas` y solo corren si cada campo por separado está bien.
- La validación revisa el **formato**. Que la categoría exista o que el cambio de estado sea el siguiente lo revisa la API después (con la BD).

## Sanitización (`sanitizar` y `limpiarTexto`)

`sanitizar` recorre el cuerpo de la petición y devuelve una copia limpia:

| Qué quita | Por qué |
|---|---|
| Etiquetas HTML (`<script>`, `<img onerror=...>`, comentarios `<!-- -->`) | Que nadie guarde código que otra pantalla pueda ejecutar. Se repite hasta que no quede ninguna, para que `<scr<b>ipt>` tampoco pase |
| Caracteres de control (byte nulo, escape de terminal...) | Nunca vienen en un texto escrito por una persona y pueden romper los logs o cortar el texto |
| Caracteres invisibles y los que invierten el texto | Sirven para disfrazar un texto (`archivo‮gnp.exe` se ve como `archivoexe.png`) |
| Las llaves `__proto__`, `constructor` y `prototype` | Evitan que un JSON cambie el comportamiento de todos los objetos del servidor (prototype pollution) |
| JSON con más de 5 niveles | Esta API no los necesita; responde `400 VALIDACION` |

Además une las letras con acento escritas en dos partes (`e` + `´` → `é`, normalización NFC), para que el largo y la búsqueda funcionen igual.

Qué **no** toca:

- **Las contraseñas** (cualquier campo que empiece con `contrasena`): limpiarlas cambiaría la contraseña que eligió la persona.
- Un `<` o `>` que no forma una etiqueta: `"La rampa mide < 2 m"` queda igual. Lo que sí parece etiqueta se quita aunque no lo sea (`"a<b y c>d"` queda `"ad"`); es poco probable en un reporte y es el precio de quitar el HTML.
- Las comillas, los punto y coma ni nada que parezca SQL: no se escapan ni se borran.

La query y los parámetros de la URL no pasan por `sanitizar` (Express 5 no deja reemplazar `req.query`); los limpia la regla `texto` al validarlos.

## Inyección SQL: consultas parametrizadas

La sanitización **no** es la defensa contra la inyección SQL. La defensa es que **todas las consultas pasan por Prisma**, que manda los valores aparte del SQL: un texto como `'; DROP TABLE reportes; --` se guarda y se busca como texto y nunca se ejecuta.

Reglas para el código:

- Usar las funciones de `backend/src/db/` (o el cliente de Prisma), nunca SQL armado pegando texto.
- **Prohibido** `$queryRawUnsafe` y `$executeRawUnsafe`. Si hace falta SQL a mano, solo con plantilla etiquetada: `` prisma.$queryRaw`SELECT ... WHERE id = ${id}` `` (Prisma la parametriza).
- Hay una prueba que revisa `src/` y falla si aparece alguno de los dos.

Las pruebas encontraron que Prisma **no escapa los comodines de `LIKE`** (`%` y `_`): buscar `%` devolvía todos los reportes. No es una inyección (el valor sigue parametrizado), pero el filtro daba resultados equivocados. Se corrigió en `listarReportes` con `escaparLike` (`backend/src/db/reportes.ts`).

## Pruebas

| Archivo | Qué prueba |
|---|---|
| `tests/sanitizacion.test.ts` | Entradas maliciosas básicas: XSS (`<script>`, `<img onerror>`, `javascript:`, etiquetas anidadas), byte nulo, caracteres invisibles, prototype pollution, JSON muy anidado. Y que no estropea textos normales, acentos, emojis ni contraseñas |
| `tests/validacion.test.ts` | Cada esquema del contrato: campos obligatorios, tipos equivocados, largos (con emojis), rangos de coordenadas, ids inválidos o enormes, filtros repetidos, campos de más (`nombre_rol`) |
| `tests/sanitizacion.integracion.test.ts` | Contra la **BD real**: inyecciones SQL guardadas como texto, las tablas intactas, búsqueda con SQL y con comodines, y la revisión de `src/` |
| `tests/app.test.js` | Que `app.js` pasa el cuerpo por `sanitizar` |

Las de BD real necesitan `docker compose up -d` con la BD migrada y sembrada; si no está, se saltan solas.

## Qué falta (lo hace la API)

- Poner `validar(esquemas.xxx)` en cada ruta al crearla (#24, #30, #31, #38, #45, #46).
- Responder `400 VALIDACION` con `campos: { id_categoria: "No existe" }` si `crearReporte` falla porque la categoría no existe (error `P2003` de Prisma), en vez de un `500`.
- La subida de imágenes (`multipart/form-data`) no pasa por `express.json()`: su validación (tipo y tamaño) va con #45. El `:id` sí se valida con `esquemas.idReporte`.
