// Configuración de Prisma 7 (en la 7.10+ se llama prisma7.config.ts para no chocar con Prisma 8).
// Los comandos de Prisma se corren desde backend/.
import { fileURLToPath } from "node:url";
import { config } from "dotenv";
import { defineConfig, env } from "prisma/config";

// Prisma 7 no lee el .env solo. El .env del proyecto vive en la raíz del repo;
// la ruta se calcula desde este archivo para que funcione desde cualquier carpeta.
config({ path: fileURLToPath(new URL("../.env", import.meta.url)), quiet: true });

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
    // `npm run db:seed` (prisma db seed) corre este comando. En Prisma 7 no se ejecuta solo después de migrar.
    seed: "tsx prisma/seed.ts",
  },
  datasource: {
    url: env("DATABASE_URL"),
    // BD temporal que usa `prisma migrate dev` para detectar cambios (solo desarrollo).
    // Es opcional: los demás comandos (deploy, generate, status) no la necesitan.
    shadowDatabaseUrl: process.env.SHADOW_DATABASE_URL || undefined,
  },
});
