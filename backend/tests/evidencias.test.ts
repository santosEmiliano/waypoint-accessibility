import { beforeEach, describe, expect, it, vi } from "vitest";

// Se reemplaza el cliente de Prisma: así las pruebas no necesitan la BD levantada.
const prisma = vi.hoisted(() => ({
  evidencia: { create: vi.fn(), findMany: vi.fn(), groupBy: vi.fn() },
  reporte: { findFirst: vi.fn() },
})) as any;
vi.mock("../src/db/prisma", () => ({ prisma }));

import {
  LARGO_MAXIMO_RUTA,
  RutaDuplicadaError,
  contarEvidenciasPorTipo,
  guardarEvidencia,
  listarEvidencias,
} from "../src/db/evidencias";

const datos = { idReporte: 7, idUsuario: 5, tipo: "reporte" as const, ruta: " /uploads/abc.jpg " };

beforeEach(() => {
  vi.resetAllMocks();
});

describe("guardarEvidencia", () => {
  it("guarda el reporte, quien la subió, el tipo y la ruta recortada", async () => {
    prisma.evidencia.create.mockResolvedValue({ idEvidencia: 31 });
    const evidencia = await guardarEvidencia(datos);

    expect(evidencia).toEqual({ idEvidencia: 31 });
    expect(prisma.evidencia.create.mock.calls[0][0].data).toEqual({
      idReporte: 7,
      idUsuario: 5,
      tipoEvidencia: "reporte",
      rutaEvidencia: "/uploads/abc.jpg",
    });
  });

  it("devuelve a quien la subió solo con id y nombre (sin correo)", async () => {
    prisma.evidencia.create.mockResolvedValue({});
    await guardarEvidencia({ ...datos, tipo: "atencion" });
    const llamada = prisma.evidencia.create.mock.calls[0][0];
    expect(llamada.data.tipoEvidencia).toBe("atencion");
    expect(llamada.select.usuario).toEqual({ select: { idUsuario: true, nombreUsuario: true } });
  });

  it("una ruta repetida lanza RutaDuplicadaError", async () => {
    prisma.evidencia.create.mockRejectedValue(Object.assign(new Error("único"), { code: "P2002" }));
    await expect(guardarEvidencia(datos)).rejects.toBeInstanceOf(RutaDuplicadaError);
  });

  it("si el reporte no existe deja pasar el error de la llave foránea", async () => {
    const llaveForanea = Object.assign(new Error("llave foránea"), { code: "P2003" });
    prisma.evidencia.create.mockRejectedValue(llaveForanea);
    await expect(guardarEvidencia(datos)).rejects.toBe(llaveForanea);
  });

  it.each([
    ["vacía", "   "],
    ["más larga que la columna", `/uploads/${"a".repeat(LARGO_MAXIMO_RUTA)}`],
  ])("rechaza una ruta %s sin tocar la BD", async (_caso, ruta) => {
    await expect(guardarEvidencia({ ...datos, ruta })).rejects.toThrow(/ruta/);
    expect(prisma.evidencia.create).not.toHaveBeenCalled();
  });

  it("rechaza un tipo que no es reporte ni atencion", async () => {
    await expect(guardarEvidencia({ ...datos, tipo: "otro" as any })).rejects.toThrow(/Tipo/);
    expect(prisma.evidencia.create).not.toHaveBeenCalled();
  });
});

describe("listarEvidencias", () => {
  it("salen de la más antigua a la más reciente", async () => {
    prisma.reporte.findFirst.mockResolvedValue({ idReporte: 7 });
    prisma.evidencia.findMany.mockResolvedValue([{ idEvidencia: 31 }]);
    expect(await listarEvidencias(7)).toEqual([{ idEvidencia: 31 }]);

    const llamada = prisma.evidencia.findMany.mock.calls[0][0];
    expect(llamada.where).toEqual({ idReporte: 7 });
    expect(llamada.orderBy).toEqual([{ creacionEvidencia: "asc" }, { idEvidencia: "asc" }]);
  });

  it("un usuario solo ve las de sus reportes; el de otro responde null y no lee las fotos", async () => {
    prisma.reporte.findFirst.mockResolvedValue(null);
    expect(await listarEvidencias(7, { idUsuario: 99 })).toBeNull();
    expect(prisma.reporte.findFirst.mock.calls[0][0].where).toEqual({ idReporte: 7, idUsuario: 99 });
    expect(prisma.evidencia.findMany).not.toHaveBeenCalled();
  });

  it("sin idUsuario (el operador) busca entre todos los reportes", async () => {
    prisma.reporte.findFirst.mockResolvedValue({ idReporte: 7 });
    prisma.evidencia.findMany.mockResolvedValue([]);
    expect(await listarEvidencias(7)).toEqual([]);
    expect(prisma.reporte.findFirst.mock.calls[0][0].where).toEqual({ idReporte: 7 });
  });
});

describe("contarEvidenciasPorTipo", () => {
  it("cuenta las de cada tipo del reporte", async () => {
    prisma.evidencia.groupBy.mockResolvedValue([
      { tipoEvidencia: "reporte", _count: { _all: 2 } },
      { tipoEvidencia: "atencion", _count: { _all: 1 } },
    ]);
    expect(await contarEvidenciasPorTipo(7)).toEqual({ reporte: 2, atencion: 1 });

    const llamada = prisma.evidencia.groupBy.mock.calls[0][0];
    expect(llamada.where).toEqual({ idReporte: 7 });
    expect(llamada.by).toEqual(["tipoEvidencia"]);
  });

  it("los tipos sin fotos salen en 0 (sin atencion no se puede pasar a Resuelto)", async () => {
    prisma.evidencia.groupBy.mockResolvedValue([{ tipoEvidencia: "reporte", _count: { _all: 3 } }]);
    expect(await contarEvidenciasPorTipo(7)).toEqual({ reporte: 3, atencion: 0 });
  });

  it("un reporte sin fotos da 0 y 0", async () => {
    prisma.evidencia.groupBy.mockResolvedValue([]);
    expect(await contarEvidenciasPorTipo(7)).toEqual({ reporte: 0, atencion: 0 });
  });
});
