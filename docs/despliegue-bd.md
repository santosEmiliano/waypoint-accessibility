# Despliegue de la BD

Cómo se pone la BD (MySQL y Redis) en la nube (issue #44). Va en un **droplet de DigitalOcean de 6 USD al mes**, el mismo servidor donde va el backend (#47). Se eligió así porque el proyecto dura alrededor de un mes: se cobra por segundo y al final se borra el droplet.

- **Persistencia:** los datos viven en los volúmenes de Docker, así que no se pierden al reiniciar los contenedores ni el servidor.
- **Credenciales:** solo están en el `.env` del servidor, nunca en el repo.
- **Sin acceso desde internet:** MySQL y Redis escuchan solo en `127.0.0.1` del servidor. El backend los usa desde ahí y el equipo entra con un túnel SSH.

```
 Internet ──► 22 (SSH), 80 y 443 (backend con HTTPS)
               │
          ┌────┴──────────── droplet ────────────────┐
          │  backend  ──►  mysql (127.0.0.1:3306)    │
          │           ──►  redis (127.0.0.1:6379)    │
          └──────────────────────────────────────────┘
```

## Archivos

| Archivo | Para qué |
|---|---|
| `docker-compose.yml` | El mismo de desarrollo: MySQL 8.4 y Redis, con los puertos solo en `127.0.0.1` y volúmenes |
| `docker-compose.prod.yml` | Ajustes del servidor, encima del anterior: `restart: always` y MySQL con menos memoria para que quepa en 1 GB |
| `.env` del servidor | Contraseñas de producción. Se crea a mano en el servidor; no se sube |

Con los ajustes, MySQL usa unos 210 MB y Redis unos 6 MB (medido con las migraciones y la semilla).

## 1. Crear el droplet

En DigitalOcean: **Create → Droplets**.

| Opción | Valor |
|---|---|
| Región | San Francisco o Nueva York (las más cercanas a México) |
| Imagen | Ubuntu 24.04 LTS |
| Tamaño | Basic → Regular → **6 USD/mes** (1 GB de RAM, 1 CPU, 25 GB) |
| Autenticación | **SSH Key** (no contraseña). Si no tienes una: `ssh-keygen -t ed25519` y pega el contenido de `~/.ssh/id_ed25519.pub` |
| Backups | No (cuestan extra; para un mes basta el respaldo manual del paso 7) |

Después, en **Networking → Firewalls**, crea un firewall con estas reglas de entrada y aplícalo al droplet:

| Puerto | Para qué |
|---|---|
| 22 | SSH |
| 80 y 443 | El backend con HTTPS (#47) |

**No abras el 3306 ni el 6379.**

## 2. Preparar el servidor

Desde tu computadora:

```bash
ssh root@IP_DEL_DROPLET
```

Ya en el servidor:

```bash
# Actualizar e instalar Docker
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh

# 1 GB de swap: con MySQL, Redis y el backend en 1 GB de RAM, evita que el sistema mate un proceso
fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# El código
git clone https://github.com/santosEmiliano/waypoint-accessibility.git /opt/waypoint
cd /opt/waypoint
```

## 3. El `.env` del servidor

```bash
cp .env.example .env
chmod 600 .env     # solo root lo puede leer
nano .env
```

Qué cambiar respecto al de desarrollo:

| Variable | Valor en el servidor |
|---|---|
| `NODE_ENV` | `production` |
| `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD`, `JWT_SECRET` | Nuevas y largas. Genera cada una con `openssl rand -hex 24` (solo letras y números, como pide `.env.example`). **Nunca** las de desarrollo |
| `DATABASE_URL` y `REDIS_URL` | Con las contraseñas nuevas (ver el paso 6 si el backend corre en Docker) |
| `SHADOW_DATABASE_URL` | Se borra: solo sirve para crear migraciones en desarrollo |
| `SEED_OPERADOR_CORREO` y `SEED_OPERADOR_CONTRASENA` | El operador real de la demo, con una contraseña fuerte |

Las contraseñas se pasan al equipo por privado, nunca por el repo ni por el chat del grupo.

## 4. Levantar MySQL y Redis

```bash
cd /opt/waypoint
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --wait
docker compose ps        # los dos deben decir "healthy"
```

## 5. Migraciones y semilla

Se corren desde tu computadora, por un túnel SSH. El servidor no necesita Node para la BD.

En una terminal, abre el túnel y déjala abierta. Tu puerto 3307 queda conectado al 3306 del servidor:

```bash
ssh -N -L 3307:127.0.0.1:3306 root@IP_DEL_DROPLET
```

En otra terminal, desde `backend/`, usa las credenciales de producción solo para estos comandos (las variables de la terminal tienen prioridad sobre tu `.env`):

```bash
export DATABASE_URL="mysql://waypoint_user:CONTRASENA_DB@127.0.0.1:3307/waypoint"
export SEED_OPERADOR_CORREO="..."  SEED_OPERADOR_CONTRASENA="..."
npm run db:deploy      # crea las tablas
npm run db:seed        # roles, categorías, estados y el operador
npm run db:status      # debe decir que está al día
```

Al terminar, cierra esa terminal para que las variables no se queden.

Cada vez que se mergee una migración nueva a `main`, se repite `npm run db:deploy` por el túnel.

## 6. Conectar el backend (#47)

El backend corre en el mismo servidor y lee el mismo `.env`:

| Si el backend corre... | `DATABASE_URL` | `REDIS_URL` |
|---|---|---|
| Directo en el servidor (Node instalado) | `mysql://waypoint_user:...@127.0.0.1:3306/waypoint` | `redis://default:...@127.0.0.1:6379` |
| En un contenedor del mismo `docker compose` | `mysql://waypoint_user:...@mysql:3306/waypoint` | `redis://default:...@redis:6379` |

`mysql` es el nombre del servicio en la red interna de Docker. `backend/src/db/prisma.ts` lo trata igual que `127.0.0.1` porque la contraseña no sale del servidor. Contra cualquier otro host exige TLS.

## 7. Comprobar y respaldar

**Que los datos sobreviven a un reinicio** (criterio de #44):

```bash
docker compose exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" waypoint -e "SELECT COUNT(*) FROM categorias"'
reboot
# Espera un minuto, vuelve a entrar por SSH y repite el SELECT: debe dar lo mismo.
```

**Respaldo manual** (antes de algo riesgoso y antes de borrar el droplet):

```bash
cd /opt/waypoint
docker compose exec -T mysql sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction waypoint' > respaldo.sql
```

Y desde tu computadora, para bajarlo: `scp root@IP_DEL_DROPLET:/opt/waypoint/respaldo.sql .`

**Entrar a la BD con Workbench:** abre el túnel del paso 5 y conéctate a `127.0.0.1`, puerto `3307`, con el usuario de `DB_USER`.

## Ojo

- `docker compose down -v` **borra los datos** (los volúmenes). Para detener sin borrar: `docker compose down`.
- Un droplet apagado **se sigue cobrando**. Al terminar el proyecto: respaldo, y luego **Destroy** en DigitalOcean.
- Docker se salta el firewall de Ubuntu (`ufw`) en los puertos que publica. Por eso MySQL y Redis van en `127.0.0.1` y el firewall que cuenta es el de DigitalOcean.
