// Paginación del listado y resumen por estado contra la BD REAL.
// Las fechas se guardan al segundo (DATETIME(0)), así que los reportes de la prueba se crean con la
// misma fecha: justo el caso en que el desempate por id evita que una página repita o salte reportes.
// Si la BD no está disponible se salta sola, igual que las demás pruebas de integración.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/db/prisma";
import { contarReportesPorEstado, crearReporte, listarReportes } from "../src/db/reportes";

async function hayBd(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return (await prisma.estado.count()) === 4 && (await prisma.categoria.count()) >= 1;
  } catch {
    return false;
  }
}

const disponible = await hayBd();
const marca = `prueba-paginacion-${Date.now()}`;

describe.skipIf(!disponible)("paginación y resumen (BD real)", () => {
  let idUsuario: number;
  let ids: number[] = [];
  let estados: { idEstado: number; ordenEstado: number }[];

  beforeAll(async () => {
    const rol = await prisma.rol.findUniqueOrThrow({ where: { nombreRol: "usuario" } });
    const categoria = await prisma.categoria.findFirstOrThrow();
    const usuario = await prisma.usuario.create({
      data: { nombreUsuario: "Prueba", correoUsuario: `${marca}@prueba.test`, contrasenaUsuario: "x", idRol: rol.idRol },
    });
    idUsuario = usuario.idUsuario;
    estados = await prisma.estado.findMany({ orderBy: { ordenEstado: "asc" } });

    // 5 reportes: 2 se quedan en Reportado, 2 pasan a En revisión y 1 se cancela
    for (let i = 1; i <= 5; i++) {
      const reporte = await crearReporte({
        idUsuario,
        titulo: `${marca} ${i}`,
        descripcion: i === 5 ? "rampa rota" : "sin rampa",
        idCategoria: categoria.idCategoria,
        ubicacion: "Edificio 1",
      });
      ids.push(reporte.idReporte);
    }
    await prisma.reporte.updateMany({ where: { idReporte: { in: [ids[2], ids[3]] } }, data: { idEstado: estados[1].idEstado } });
    await prisma.reporte.update({ where: { idReporte: ids[4] }, data: { canceladoReporte: true } });
  });

  afterAll(async () => {
    if (ids.length) {
      await prisma.historial.deleteMany({ where: { idReporte: { in: ids } } });
      await prisma.reporte.deleteMany({ where: { idReporte: { in: ids } } });
    }
    if (idUsuario) await prisma.usuario.delete({ where: { idUsuario } });
  });

  it("las páginas juntas dan la lista completa, sin repetir ni saltar, del más nuevo al más viejo", async () => {
    const completa = await listarReportes({ idUsuario });
    const paginas = [
      await listarReportes({ idUsuario }, { limite: 2, desde: 0 }),
      await listarReportes({ idUsuario }, { limite: 2, desde: 2 }),
      await listarReportes({ idUsuario }, { limite: 2, desde: 4 }),
    ];
    expect(paginas.map((p) => p.length)).toEqual([2, 2, 0]);
    expect(paginas.flat().map((r) => r.idReporte)).toEqual(completa.map((r) => r.idReporte));
    // Sin el cancelado, y con la misma fecha manda el id más alto
    expect(completa.map((r) => r.idReporte)).toEqual([ids[3], ids[2], ids[1], ids[0]]);
  });

  it("por actualización, primero el que cambió más recientemente", async () => {
    // Se fija la fecha a mano porque todo pasa en el mismo segundo
    await prisma.reporte.update({
      where: { idReporte: ids[0] },
      data: { actualizacionReporte: new Date(Date.now() + 60_000) },
    });
    const lista = await listarReportes({ idUsuario }, { orden: "actualizacion", limite: 1 });
    expect(lista.map((r) => r.idReporte)).toEqual([ids[0]]);
  });

  it("el resumen trae los 4 estados, sin contar el cancelado", async () => {
    const resumen = await contarReportesPorEstado({ idUsuario });
    expect(resumen).toEqual(estados.map(({ idEstado }, i) => ({ idEstado, total: [2, 2, 0, 0][i] })));
  });

  it("el resumen respeta el texto de búsqueda", async () => {
    // "rampa rota" solo está en el cancelado: no cuenta
    const resumen = await contarReportesPorEstado({ idUsuario, texto: "rampa rota" });
    expect(resumen.map((e) => e.total)).toEqual([0, 0, 0, 0]);
  });

  it("el resumen de un usuario no cuenta los reportes de los demás", async () => {
    const deNadie = await contarReportesPorEstado({ idUsuario: 4_294_967_295 });
    expect(deNadie.map((e) => e.total)).toEqual([0, 0, 0, 0]);
  });
});
