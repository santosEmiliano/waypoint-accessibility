// La conexión a Redis se abre una sola vez aunque lleguen varias peticiones a la vez.
// Usa un cliente falso: no necesita Redis levantado.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { createClient } = vi.hoisted(() => ({ createClient: vi.fn() }));
vi.mock("redis", () => ({ createClient }));

const { obtenerRedis, cerrarRedis } = await import("../src/redis");

// Cliente falso cuya conexión termina cuando la prueba decide
function clienteFalso(conectar: () => Promise<void> = () => Promise.resolve()) {
  return { on: vi.fn(), connect: vi.fn(conectar), quit: vi.fn(() => Promise.resolve()) };
}

beforeEach(() => {
  process.env.REDIS_URL = "redis://127.0.0.1:6379";
  createClient.mockReset();
});

afterEach(async () => {
  await cerrarRedis();
});

describe("obtenerRedis", () => {
  it("dos peticiones a la vez antes de conectar comparten un solo cliente", async () => {
    let terminarConexion!: () => void;
    const cliente = clienteFalso(() => new Promise<void>((resolve) => (terminarConexion = resolve)));
    createClient.mockReturnValue(cliente);

    const primera = obtenerRedis();
    const segunda = obtenerRedis();
    terminarConexion();

    expect(await primera).toBe(cliente);
    expect(await segunda).toBe(cliente);
    expect(createClient).toHaveBeenCalledTimes(1);
    expect(cliente.connect).toHaveBeenCalledTimes(1);
  });

  it("ya conectado, devuelve el mismo cliente", async () => {
    createClient.mockReturnValue(clienteFalso());
    const primero = await obtenerRedis();
    expect(await obtenerRedis()).toBe(primero);
    expect(createClient).toHaveBeenCalledTimes(1);
  });

  it("si la conexión falla, la siguiente petición lo vuelve a intentar", async () => {
    createClient.mockReturnValueOnce(clienteFalso(() => Promise.reject(new Error("ECONNREFUSED"))));
    await expect(obtenerRedis()).rejects.toThrow("ECONNREFUSED");

    const bueno = clienteFalso();
    createClient.mockReturnValueOnce(bueno);
    expect(await obtenerRedis()).toBe(bueno);
    expect(createClient).toHaveBeenCalledTimes(2);
  });

  it("cerrarRedis cierra el cliente y la siguiente petición abre uno nuevo", async () => {
    const primero = clienteFalso();
    createClient.mockReturnValueOnce(primero);
    await obtenerRedis();
    await cerrarRedis();
    expect(primero.quit).toHaveBeenCalledTimes(1);

    const segundo = clienteFalso();
    createClient.mockReturnValueOnce(segundo);
    expect(await obtenerRedis()).toBe(segundo);
  });

  it("sin REDIS_URL lanza un error claro", async () => {
    delete process.env.REDIS_URL;
    await expect(obtenerRedis()).rejects.toThrow("Falta REDIS_URL");
    expect(createClient).not.toHaveBeenCalled();
  });
});
