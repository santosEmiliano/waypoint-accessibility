// Única conexión a la BD. La semilla y todas las funciones de acceso a datos importan `prisma` de aquí.
import { fileURLToPath } from "node:url";
import { config } from "dotenv";
import { PrismaMariaDb } from "@prisma/adapter-mariadb";
import { PrismaClient } from "../generated/prisma/client";

// El .env vive en la raíz del repo (tres carpetas arriba de este archivo).
config({ path: fileURLToPath(new URL("../../../.env", import.meta.url)), quiet: true });

const urlBd = process.env.DATABASE_URL;
if (!urlBd) {
  throw new Error("Falta DATABASE_URL en el .env");
}

// Hosts donde la contraseña no sale del servidor: esta computadora, o el servicio `mysql` de
// docker compose, al que solo se llega por la red interna de Docker (el backend desplegado en el
// mismo servidor, ver docs/despliegue-bd.md).
const HOSTS_LOCALES = ["127.0.0.1", "localhost", "[::1]", "mysql"];

// Separa DATABASE_URL en las opciones que pide el adaptador de MySQL.
export function opcionesAdaptador(urlTexto: string) {
  const url = new URL(urlTexto);
  return {
    host: url.hostname,
    port: Number(url.port || 3306),
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    database: url.pathname.slice(1),
    connectionLimit: 5,
    // Cuánto espera una consulta por una conexión libre. Con el valor por defecto (10 s) y el
    // reintento de Prisma, si la BD se cae cada petición tarda unos 20 s en fallar; con 3 s, unos 6 s
    // (medido en tests/bd-caida.test.ts). Con 5 conexiones y consultas cortas sobra para la carga normal.
    acquireTimeout: 3000,
    // MySQL 8 pide un intercambio de llave RSA y el adaptador lo rechaza sin esto.
    // Solo se permite contra la BD local (HOSTS_LOCALES): con una BD remota se expondría la
    // contraseña a un intermediario, así que allá hay que conectarse con TLS.
    allowPublicKeyRetrieval: HOSTS_LOCALES.includes(url.hostname),
  };
}

const adapter = new PrismaMariaDb(opcionesAdaptador(urlBd));

export const prisma = new PrismaClient({ adapter });
