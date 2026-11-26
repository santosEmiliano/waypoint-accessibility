// Qué pasa si la BD no responde (#50). Se usa la misma configuración de src/db/prisma.ts, pero
// apuntando a un puerto donde no hay nadie (127.0.0.1:1). No necesita la BD levantada.
import { describe, expect, it, vi } from "vitest";

vi.mock("../src/db/prisma", async (importOriginal) => {
  const original = await importOriginal<typeof import("../src/db/prisma")>();
  const { PrismaMariaDb } = await import("@prisma/adapter-mariadb");
  const { PrismaClient } = await import("../src/generated/prisma/client");
  const adapter = new PrismaMariaDb(original.opcionesAdaptador("mysql://u:p@127.0.0.1:1/waypoint"));
  return { ...original, prisma: new PrismaClient({ adapter }) };
});

const { prisma } = await import("../src/db/prisma");
const { buscarUsuarioPorId } = await import("../src/db/usuarios");

// Con acquireTimeout de 3 s y el reintento de Prisma tarda unos 6 s
const ESPERA_MAXIMA_MS = 9000;

describe("si la BD no responde", () => {
  it(`la consulta falla en menos de ${ESPERA_MAXIMA_MS / 1000} s, con la causa real, en vez de quedarse colgada`, async () => {
    const inicio = Date.now();
    const error = await prisma.$queryRaw`SELECT 1`.catch((e: unknown) => e);
    const tardo = Date.now() - inicio;

    expect(error).toBeInstanceOf(Error);
    // La causa (conexión rechazada) viene dentro de meta; server.ts la muestra al arrancar
    expect(JSON.stringify((error as { meta?: unknown }).meta)).toContain("ECONNREFUSED");
    expect(tardo).toBeLessThan(ESPERA_MAXIMA_MS);
  }, 20_000);

  it("las funciones de src/db lanzan el error en vez de devolver null", async () => {
    // Si devolviera null, autenticar creería que el usuario no existe y respondería 401 (cerraría la
    // sesión de todos). Con el error, la petición termina en 500 ERROR_INTERNO (tests/cadena-middlewares.test.ts).
    await expect(buscarUsuarioPorId(1)).rejects.toThrow();
  }, 20_000);
});
