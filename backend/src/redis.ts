// Única conexión a Redis (sesiones activas). Se abre la primera vez que se usa,
// para que importar este archivo no falle si Redis no está levantado (por ejemplo en las pruebas).
import { fileURLToPath } from "node:url";
import { config } from "dotenv";
import { createClient, type RedisClientType } from "redis";

config({ path: fileURLToPath(new URL("../../.env", import.meta.url)), quiet: true });

// Se guarda la promesa de la conexión, no el cliente: si llegan varias peticiones mientras se
// conecta, todas esperan la misma conexión en vez de abrir un cliente cada una.
let conexion: Promise<RedisClientType> | undefined;

async function conectar(): Promise<RedisClientType> {
  const url = process.env.REDIS_URL;
  if (!url) throw new Error("Falta REDIS_URL en el .env");
  const nuevo = createClient({ url }) as RedisClientType;
  nuevo.on("error", (error) => console.error("Error de Redis:", error.message));
  await nuevo.connect();
  return nuevo;
}

export function obtenerRedis(): Promise<RedisClientType> {
  if (!conexion) {
    conexion = conectar().catch((error) => {
      // Si no se pudo conectar, la siguiente petición lo vuelve a intentar
      conexion = undefined;
      throw error;
    });
  }
  return conexion;
}

export async function cerrarRedis(): Promise<void> {
  const pendiente = conexion;
  conexion = undefined;
  if (pendiente) {
    const cliente = await pendiente.catch(() => undefined);
    await cliente?.quit();
  }
}
