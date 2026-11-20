# Acuerdos entre la BD y la API

Decisiones de la base de datos que afectan cómo Harim programa la API. Lo mantiene Julián. Si algo de aquí choca con `docs/api.md`, se habla antes de cambiarlo.

## Roles

- Los roles se llaman **`operador`** y **`usuario`** (no `admin`). Viven en la tabla catálogo `roles`.
- `usuarios.id_rol` es una llave foránea hacia `roles.id_rol`. La BD rechaza un usuario con un rol que no existe.
- Las cuentas creadas con `POST /auth/registro` nacen como `usuario`. Los operadores vienen de la semilla.

## Contraseñas

- La columna **`usuarios.contrasena_usuario` guarda el hash de bcrypt, nunca la contraseña real.**
- La API recibe la contraseña, le saca el hash con bcrypt y guarda solo ese hash. En el login compara con `bcrypt.compare`.
- `contrasena_usuario` nunca se devuelve en una respuesta de la API.

## Estados y validación de transiciones

La tabla `estados` tiene la columna **`orden_estado`**:

| nombre_estado | orden_estado |
|---|---|
| Reportado | 1 |
| En análisis | 2 |
| En atención | 3 |
| Resuelto | 4 |

**Cómo se valida una transición:** el cambio es válido solo si

```
orden_estado del estado nuevo = orden_estado del estado actual + 1
```

- Reportado (1) → En análisis (2): válido.
- Reportado (1) → En atención (3): inválido, porque se salta un paso.
- En atención (3) → En análisis (2): inválido, porque retrocede.

Así la API no necesita una lista fija de transiciones permitidas, y la regla funciona aunque cambien los nombres.

**No usar `id_estado` como orden.** El id lo genera MySQL y no tiene significado. Si se reinsertara un estado, cambiaría de número. El orden siempre se toma de `orden_estado`.

`GET /estados` debe ordenar por `orden_estado`.

## Reportes

- `id_operador` es `NULL` mientras nadie toma el reporte. Para asignar sin que dos operadores choquen: `UPDATE ... WHERE id_operador IS NULL`; si afecta 0 filas, responder `409`.
- `id_estado` no tiene valor por defecto: al crear un reporte se usa el estado con `orden_estado = 1`.
- Latitud y longitud son opcionales (pueden ir `NULL` si no hay permiso de GPS); `ubicacion_reporte` (texto) es obligatorio.
- Cancelar = `cancelado_reporte = 1`. Los reportes nunca se borran.
- `razon_cancelacion_reporte` (`TEXT`) es **opcional**: el usuario puede cancelar sin escribir una razón. Es `NULL` mientras el reporte no está cancelado o si se canceló sin razón. Se guarda solo en `reportes`, no en `historial` (el renglón de tipo `cancelacion` deja `descripcion_historial` en `NULL`). El límite de caracteres lo pone la API, como en `descripcion_reporte`.

## Evidencias

- `tipo_evidencia` es un `ENUM('reporte','atencion')`: la BD rechaza cualquier otro valor.
- En la BD solo se guarda `ruta_evidencia` (el nombre del archivo en `uploads/`), no la imagen.
- **El nombre del archivo lo genera el servidor (por ejemplo, un UUID).** Nunca usar el nombre que manda el cliente, para evitar *path traversal* (`../../archivo`).
- Quitar una foto es **borrado físico**: se elimina la fila y la API borra el archivo del disco.

## Acciones correctivas

- `POST /reportes/:id/acciones` **no tiene tabla propia: se guarda en `historial`**, igual que los cambios de estado. Así `GET /reportes/:id/historial` muestra la línea de tiempo completa con una sola consulta.
- *Pendiente:* las columnas exactas de `historial` se definen en el ERD v1.

## Catálogos

- `categorias` y `estados` son de solo lectura para la API. Sus datos vienen de la semilla de la BD.
