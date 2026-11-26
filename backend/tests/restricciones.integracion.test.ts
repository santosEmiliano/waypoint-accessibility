// Restricciones de la BD REAL (#51): se intenta guardar datos inconsistentes saltándose la API y las
// funciones de src/db, directo con Prisma, y la BD los tiene que rechazar sola.
// Si la BD no está disponible se saltan solas, igual que las demás pruebas de integración.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/db/prisma";
import { crearReporte } from "../src/db/reportes";

async function hayBd(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return (await prisma.estado.count()) === 4 && (await prisma.categoria.count()) >= 1;
  } catch {
    return false;
  }
}

const disponible = await hayBd();
const marca = `prueba-restricciones-${Date.now()}`;

describe.skipIf(!disponible)("restricciones de la BD (BD real)", () => {
  let idUsuario: number;
  let idRolUsuario: number;
  let idCategoria: number;
  let idReporte: number;
  // Por orden: Reportado, En análisis, En atención, Resuelto
  let estados: number[];
  let rutas = 0;

  const reporteValido = () => ({
    idUsuario,
    idCategoria,
    idEstado: estados[0],
    tituloReporte: marca,
    descripcionReporte: "d",
    ubicacionReporte: "u",
  });
  const historialValido = () => ({ idReporte, idUsuario });

  beforeAll(async () => {
    idRolUsuario = (await prisma.rol.findUniqueOrThrow({ where: { nombreRol: "usuario" } })).idRol;
    const usuario = await prisma.usuario.create({
      data: { nombreUsuario: "Restricciones", correoUsuario: `${marca}@prueba.test`, contrasenaUsuario: "x", idRol: idRolUsuario },
    });
    idUsuario = usuario.idUsuario;
    idCategoria = (await prisma.categoria.findFirstOrThrow()).idCategoria;
    estados = (await prisma.estado.findMany({ orderBy: { ordenEstado: "asc" } })).map((e) => e.idEstado);
    idReporte = (await crearReporte({ idUsuario, titulo: marca, descripcion: "d", idCategoria, ubicacion: "u" })).idReporte;
  });

  afterAll(async () => {
    const ids = (await prisma.reporte.findMany({ where: { idUsuario }, select: { idReporte: true } })).map((r) => r.idReporte);
    await prisma.evidencia.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.historial.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.reporte.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.usuario.deleteMany({ where: { correoUsuario: { startsWith: marca } } });
    await prisma.$disconnect();
  });

  describe("reportes", () => {
    it.each([
      ["latitud mayor a 90", { latitudReporte: 90.000001, longitudReporte: 0 }, "chk_reportes_latitud"],
      ["latitud menor a -90", { latitudReporte: -91, longitudReporte: 0 }, "chk_reportes_latitud"],
      ["longitud mayor a 180", { latitudReporte: 0, longitudReporte: 180.5 }, "chk_reportes_longitud"],
      ["longitud menor a -180", { latitudReporte: 0, longitudReporte: -999 }, "chk_reportes_longitud"],
      ["solo latitud", { latitudReporte: 21.88 }, "chk_reportes_coordenadas"],
      ["título vacío", { tituloReporte: "" }, "chk_reportes_titulo"],
      ["título con solo espacios", { tituloReporte: "   " }, "chk_reportes_titulo"],
      ["descripción vacía", { descripcionReporte: " " }, "chk_reportes_descripcion"],
      ["ubicación vacía", { ubicacionReporte: "" }, "chk_reportes_ubicacion"],
      ["razón sin estar cancelado", { razonCancelacionReporte: "x" }, "chk_reportes_razon_cancelacion"],
    ])("rechaza %s", async (_caso, cambios, restriccion) => {
      await expect(prisma.reporte.create({ data: { ...reporteValido(), ...cambios } })).rejects.toThrow(restriccion);
    });

    it("acepta los extremos de las coordenadas", async () => {
      const reporte = await prisma.reporte.create({
        data: { ...reporteValido(), latitudReporte: -90, longitudReporte: 180 },
      });
      expect(Number(reporte.latitudReporte)).toBe(-90);
      expect(Number(reporte.longitudReporte)).toBe(180);
    });

    it("también revisa al actualizar, no solo al crear", async () => {
      await expect(
        prisma.reporte.update({ where: { idReporte }, data: { tituloReporte: "  " } }),
      ).rejects.toThrow("chk_reportes_titulo");
      expect((await prisma.reporte.findUniqueOrThrow({ where: { idReporte } })).tituloReporte).toBe(marca);
    });

    it("una categoría o un estado que no existen los rechaza la llave foránea", async () => {
      await expect(prisma.reporte.create({ data: { ...reporteValido(), idCategoria: 250 } })).rejects.toThrow();
      await expect(prisma.reporte.create({ data: { ...reporteValido(), idEstado: 250 } })).rejects.toThrow();
    });
  });

  describe("usuarios", () => {
    it.each([
      ["nombre vacío", { nombreUsuario: "  " }, "chk_usuarios_nombre"],
      ["correo sin arroba", { correoUsuario: `${marca}-sin-arroba` }, "chk_usuarios_correo"],
      ["correo sin nada antes de la arroba", { correoUsuario: "@prueba.test" }, "chk_usuarios_correo"],
    ])("rechaza %s", async (_caso, cambios, restriccion) => {
      const datos = { nombreUsuario: "X", correoUsuario: `${marca}-${rutas++}@prueba.test`, contrasenaUsuario: "x", idRol: idRolUsuario };
      await expect(prisma.usuario.create({ data: { ...datos, ...cambios } })).rejects.toThrow(restriccion);
    });

    it("el correo es único sin importar mayúsculas", async () => {
      await expect(
        prisma.usuario.create({
          data: { nombreUsuario: "X", correoUsuario: `${marca}@PRUEBA.TEST`.toUpperCase(), contrasenaUsuario: "x", idRol: idRolUsuario },
        }),
      ).rejects.toMatchObject({ code: "P2002" });
    });

    it("no se puede borrar un usuario que tiene reportes", async () => {
      await expect(prisma.usuario.delete({ where: { idUsuario } })).rejects.toThrow();
      expect(await prisma.usuario.count({ where: { idUsuario } })).toBe(1);
    });
  });

  describe("evidencias", () => {
    it("rechaza una ruta vacía", async () => {
      await expect(
        prisma.evidencia.create({ data: { idReporte, idUsuario, tipoEvidencia: "reporte", rutaEvidencia: " " } }),
      ).rejects.toThrow("chk_evidencias_ruta");
    });
  });

  describe("historial", () => {
    it.each([
      ["creación sin estado nuevo", { tipoHistorial: "creacion" as const }],
      ["creación con estado anterior", { tipoHistorial: "creacion" as const, idAnterior: 0, idNuevo: 1 }],
      ["cambio de estado sin el anterior", { tipoHistorial: "cambio_estado" as const, idNuevo: 1 }],
      ["cambio de estado sin el nuevo", { tipoHistorial: "cambio_estado" as const, idAnterior: 0 }],
      ["cambio de estado al mismo estado", { tipoHistorial: "cambio_estado" as const, idAnterior: 1, idNuevo: 1 }],
      ["asignación con estados", { tipoHistorial: "asignacion" as const, idAnterior: 0, idNuevo: 1 }],
      ["cancelación con estado nuevo", { tipoHistorial: "cancelacion" as const, idNuevo: 0 }],
    ])("rechaza %s", async (_caso, { tipoHistorial, idAnterior, idNuevo }: { tipoHistorial: "creacion" | "cambio_estado" | "asignacion" | "cancelacion"; idAnterior?: number; idNuevo?: number }) => {
      await expect(
        prisma.historial.create({
          data: {
            ...historialValido(),
            tipoHistorial,
            idEstadoAnterior: idAnterior === undefined ? null : estados[idAnterior],
            idEstadoNuevo: idNuevo === undefined ? null : estados[idNuevo],
          },
        }),
      ).rejects.toThrow("chk_historial_estados");
    });

    it("acepta cada tipo con los estados que le tocan", async () => {
      const filas = [
        { tipoHistorial: "cambio_estado" as const, idEstadoAnterior: estados[0], idEstadoNuevo: estados[1] },
        { tipoHistorial: "asignacion" as const },
        { tipoHistorial: "edicion" as const },
        { tipoHistorial: "accion_correctiva" as const, descripcionHistorial: "Se colocó una rampa" },
      ];
      for (const fila of filas) {
        await expect(prisma.historial.create({ data: { ...historialValido(), ...fila } })).resolves.toBeDefined();
      }
    });

    it.each([
      ["sin descripción", null],
      ["con la descripción vacía", "   "],
    ])("rechaza una acción correctiva %s", async (_caso, descripcionHistorial) => {
      await expect(
        prisma.historial.create({ data: { ...historialValido(), tipoHistorial: "accion_correctiva", descripcionHistorial } }),
      ).rejects.toThrow("chk_historial_accion_descripcion");
    });

    it("no se puede borrar un estado que ya se usó", async () => {
      await expect(prisma.estado.delete({ where: { idEstado: estados[0] } })).rejects.toThrow();
      expect(await prisma.estado.count()).toBe(4);
    });
  });

  describe("catálogos", () => {
    it("no acepta un quinto estado", async () => {
      await expect(
        prisma.estado.create({ data: { nombreEstado: `${marca}-quinto`, ordenEstado: 5 } }),
      ).rejects.toThrow("chk_estados_orden");
    });

    it("no acepta dos estados con el mismo orden", async () => {
      await expect(
        prisma.estado.create({ data: { nombreEstado: `${marca}-repetido`, ordenEstado: 1 } }),
      ).rejects.toMatchObject({ code: "P2002" });
    });
  });
});
