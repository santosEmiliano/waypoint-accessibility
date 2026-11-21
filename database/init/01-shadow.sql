-- Se ejecuta solo la primera vez que se crea el volumen de MySQL.
-- BD temporal que usa `prisma migrate dev` (SHADOW_DATABASE_URL) para detectar cambios.
-- Prisma la vacía en cada migración; no guarda datos de la app.
CREATE DATABASE IF NOT EXISTS waypoint_shadow CHARACTER SET utf8mb4;
