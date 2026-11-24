# Waypoint

Sistema de reportes de accesibilidad universitaria. Permite a los usuarios reportar obstáculos o condiciones que dificultan el acceso a las instalaciones, con fotografía, categoría y ubicación, y a un operador analizarlos, atenderlos y darles seguimiento.

Proyecto final de **Programación de Dispositivos Móviles**, Universidad Autónoma de Aguascalientes, Ingeniería en Sistemas Computacionales, 7.º semestre.

## Cómo funciona

- El **usuario** registra un reporte con categoría, descripción, ubicación y fotografías, y consulta el avance y el historial de sus reportes.
- El **operador** consulta todos los reportes, los analiza, cambia su estado, documenta las acciones correctivas y sube la fotografía de la atención realizada.
- Cada reporte pasa por cuatro estados: **Reportado → En análisis → En atención → Resuelto**.
- **Regla del sistema:** un reporte no puede marcarse como Resuelto si no tiene al menos una evidencia fotográfica de la atención realizada.
- Los permisos se comprueban en el backend. Cada cambio de estado queda registrado en el historial.

## Arquitectura

1. **Flutter** (web, iPhone y escritorio) que consume la API.
2. **Servidor backend** con una API REST.
3. **Base de datos relacional central**, a la que solo accede el backend.

## Estructura del repositorio

| Carpeta | Contenido | Responsable |
|---|---|---|
| `frontend/` | Aplicación Flutter | Santos |
| `backend/` | API REST y controladores | Harim |
| `database/` | Scripts SQL, semillas y configuración de la BD | Julián |
| `docs/` | Diagrama entidad-relación, contrato de la API, funciones de acceso a datos | Los tres |
| `.github/` | Plantilla de Pull Request y Workflows | Los tres |

## Equipo

| Integrante | Usuario de GitHub | Parte |
|---|---|---|
| Emiliano Alejandro Santos González | `santosEmiliano` | Frontend y coordinación |
| Julián Emmanuel Hernández | `JulianHernandezEmma` | Base de datos y middlewares |
| Harim Jesús Enrique Dueñas Dávila | `HarimDuenas` | API |

## Cómo trabajamos

El seguimiento está en la pestaña **Projects** del repositorio, con las columnas Pendiente, En proceso, En revisión y Terminado. Cada actividad es un Issue con responsable, criterios de aceptación y etiqueta, y pertenece a un hito que corresponde a un día de trabajo.

### Ramas

No se desarrolla directamente sobre `main`. Cada Issue se trabaja en su propia rama:

```
feature/<tema>   nueva funcionalidad
fix/<tema>       corrección de un error
docs/<tema>      documentación
chore/<tema>     configuración y mantenimiento
```

### Pull Requests

- Un Pull Request por Issue, de tamaño pequeño, con descripción y el Issue relacionado.
- **Revisión cruzada obligatoria:** Julián revisa a Harim, Harim revisa a Santos y Santos revisa a Julián.
- Nadie integra su propio Pull Request sin la aprobación de su compañero.
- Un Issue está terminado cuando funciona, su Pull Request fue aprobado e integrado, y el Issue pasó a la columna Terminado.

### Convenciones

- Código en español: variables, funciones, tablas y rutas (`reportes`, `crearReporte`), sin acentos en los nombres.
- Commits y Pull Requests en español, con el formato `tipo(scope): descripción` (ej. `feat(api): Se agregó el endpoint de login`).

## Cómo ejecutar el proyecto

Cada parte documenta aquí su instalación y ejecución cuando queda lista.

- **Base de datos:** ver [Base de datos](#base-de-datos).
- **Backend:** ver [Backend](#backend).
- **Frontend:** pendiente (Santos).

Variables de entorno: copiar `.env.example` a `.env` y completar los valores.

### Base de datos

MySQL 8.4 y Redis corren en Docker. Solo se necesita [Docker Desktop](https://www.docker.com/products/docker-desktop/).

1. Copiar `.env.example` a `.env` en la raíz del repo y poner las contraseñas. Las reales se pasan por privado; nunca se suben al repo. Usar solo letras, números, `-` y `_`: caracteres como `@ / : # $` o espacios rompen `DATABASE_URL` y `REDIS_URL`, o hacen que Docker y la API lean contraseñas distintas.
2. Levantar la BD desde la raíz:

   ```bash
   docker compose up -d
   ```

3. Revisar que los dos servicios digan `healthy`:

   ```bash
   docker compose ps
   ```

Para detenerla: `docker compose down`. Los datos se quedan guardados en los volúmenes `waypoint_mysql_datos` y `waypoint_redis_datos`.

> **Ojo:** `docker compose down -v` borra los volúmenes, o sea, **todos los datos**.

- MySQL queda en `127.0.0.1:3306` y Redis en `127.0.0.1:6379`, solo accesibles desde la misma computadora. En las URL se usa `127.0.0.1` y no `localhost`, para no terminar conectado a otro MySQL instalado en Windows.
- Si un puerto ya está ocupado, `docker compose up` falla con `ports are not available` o `address already in use`. Lo típico es el servicio **MySQL80** de Windows o el Redis de otro proyecto. Se arregla deteniendo ese servicio, o cambiando `DB_PORT` o `REDIS_PORT` en el `.env` y también el puerto dentro de `DATABASE_URL` o `REDIS_URL`.
- Si cambias `DB_USER`, `DB_PASSWORD` o `DB_ROOT_PASSWORD` después de haber levantado la BD, MySQL no los toma: solo los lee la primera vez. Hay que borrar el volumen con `down -v` y volver a levantarla.

#### Esquema con Prisma

El esquema vive en `backend/prisma/schema.prisma` y las migraciones en `backend/prisma/migrations/`. Se usa **Prisma 7.10.1**: no instalar `prisma` sin versión, porque npm baja una versión de prueba de Prisma 8. Los comandos se corren **desde `backend/`**, con la BD ya levantada:

```bash
cd backend
npm install
npm run db:deploy     # crea las tablas aplicando las migraciones
npm run db:generate   # genera el cliente de Prisma (backend/src/generated/, no se sube)
```

| Comando | Para qué |
|---|---|
| `npm run db:deploy` | Aplica las migraciones pendientes. Es el que usan todos |
| `npm run db:generate` | Vuelve a generar el cliente después de un `npm install` o de cambiar el esquema |
| `npm run db:status` | Dice si la BD está al día con las migraciones |
| `npm run db:migrate` | Solo para quien cambia `schema.prisma`: crea una migración nueva. Usa `SHADOW_DATABASE_URL` |

`db:migrate` necesita `SHADOW_DATABASE_URL` en el `.env`. Si copiaste tu `.env` antes de que existiera esa variable, agrégala desde `.env.example`; los demás comandos funcionan sin ella. La base `waypoint_shadow` la crea Docker la primera vez que se levanta MySQL (`database/init/`). Si tu volumen ya existía, créala una vez:

```bash
docker compose exec mysql mysql -uroot -p -e "CREATE DATABASE IF NOT EXISTS waypoint_shadow"
```

#### Semilla

Después de `db:deploy`, la semilla carga los datos iniciales: los roles (`usuario`, `operador`), las categorías, los 4 estados con su orden y un operador de prueba.

```bash
npm run db:seed
```

- Se puede correr las veces que sea: no duplica nada.
- El operador sale de `SEED_OPERADOR_CORREO` y `SEED_OPERADOR_CONTRASENA` del `.env` (la contraseña de mínimo 8 caracteres). Se guarda con bcrypt.
- Si el operador ya existe, la semilla **no** le cambia la contraseña.
- En Prisma 7 la semilla no corre sola después de migrar: hay que correrla a mano.

### Backend

Requiere Node.js 22.12 o superior.

1. Copiar las variables de entorno en la raíz del repositorio. El backend lee el `.env` de la raíz, no de `backend/`, y sin ese archivo no arranca.

   ```
   cp .env.example .env
   ```

2. Instalar las dependencias desde `backend/`.

   ```
   cd backend
   ```

   ```
   npm install
   ```

3. Levantar la BD y generar el cliente de Prisma, como se explica en [Base de datos](#base-de-datos) y [Esquema con Prisma](#esquema-con-prisma). Sin la BD el servidor no arranca.

4. Levantar el servidor. Se reinicia solo al guardar cambios.

   ```
   npm run dev
   ```

   Al arrancar comprueba la conexión a la BD y debe mostrar `Conectado a la BD`. Si la BD no responde, tarda unos 20 segundos, muestra la causa y se detiene.

   Para comprobar que está activo, abrir `http://localhost:3000/health`, que responde `{"estado":"ok"}`.

5. Correr las pruebas automáticas. No necesitan el servidor ni la BD levantados.

   ```
   npm test
   ```

**Pruebas en Postman:** importar `docs/postman/waypoint-api.postman_collection.json` con **Import**. Las peticiones apuntan a `http://localhost:3000`, así que el servidor debe estar levantado.

**Versión web de Flutter:** el backend solo acepta peticiones del navegador desde los orígenes de `CORS_ORIGIN` (por defecto `http://localhost:8080`). Hay que levantar la versión web en ese puerto; si Flutter elige un puerto al azar, el navegador bloquea las respuestas.

```
flutter run -d chrome --web-port=8080
```

**Errores 500:** la API solo responde `Ocurrió un error en el servidor`, sin detalles. El error completo aparece en la consola donde corre el backend.

## Documentación técnica

Se agrega en `docs/` conforme avanza el proyecto:

- Diagrama entidad-relación (Julián).
- Contrato de la API (Harim).
- Funciones de acceso a datos (Julián).
