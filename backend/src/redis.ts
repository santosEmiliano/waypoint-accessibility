// Única conexión a Redis (sesiones activas). Se abre la primera vez que se usa,
// para que importar este archivo no falle si Redis no está levantado (por ejemplo en las pruebas).
import { fileURLToPath } from "node:url";
import { config } from "dotenv";
import { createClient, type RedisClientType } from "redis";

config({ path: fileURLToPath(new URL("../../.env", import.meta.url)), quiet: true });

let cliente: RedisClientType | undefined;

export async function obtenerRedis(): Promise<RedisClientType> {
  if (!cliente) {
    const url = process.env.REDIS_URL;
    if (!url) throw new Error("Falta REDIS_URL en el .env");
    const nuevo = createClient({ url }) as RedisClientType;
    nuevo.on("error", (error) => console.error("Error de Redis:", error.message));
    await nuevo.connect();
    cliente = nuevo;
  }
  return cliente;
}

export async function cerrarRedis(): Promise<void> {
  if (cliente) {
    await cliente.quit();
    cliente = undefined;
  }
}
