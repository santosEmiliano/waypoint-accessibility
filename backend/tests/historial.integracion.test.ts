// Pruebas contra la BD REAL (MySQL de docker compose, ya migrada y con la semilla).
// Si la BD no está disponible se saltan solas, para que `npm test` no falle en una máquina sin Docker.
// Aquí se prueba lo que un mock no puede probar: que la transacción de verdad se deshace.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/db/prisma";
import { consultarHistorial } from "../src/db/historial";
import { asignarReporte, cambiarEstadoReporte, cancelarReporte, crearReporte } from "../src/db/reportes";

async function hayBd(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    const [estados, roles, categorias] = await Promise.all([
      prisma.estado.count(),
      prisma.rol.count(),
      prisma.categoria.count(),
    ]);
    return estados === 4 && roles >= 1 && categorias >= 1;
  } catch {
    return false;
  }
}

const disponible = await hayBd();

// Un id de usuario que no existe: la llave foránea del historial lo rechaza
const USUARIO_INEXISTENTE = 4_000_000_000;
const marca = `prueba-integracion-${Date.now()}`;

describe.skipIf(!disponible)("historial y transacciones (BD real)", () => {
  let idUsuario: number;
  let idOperador: number;
  let idCategoria: number;
  let estado1: number;
  let estado2: number;

  async function nuevoReporte(titulo = marca) {
    return crearReporte({ idUsuario, titulo, descripcion: "d", idCategoria, ubicacion: "u" });
  }

  const filasHistorial = (idReporte: number) => prisma.historial.count({ where: { idReporte } });

  beforeAll(async () => {
    const rol = await prisma.rol.findUniqueOrThrow({ where: { nombreRol: "usuario" } });
    const usuario = await prisma.usuario.create({
      data: { nombreUsuario: "Prueba", correoUsuario: `${marca}@prueba.test`, contrasenaUsuario: "x", idRol: rol.idRol },
    });
    idUsuario = usuario.idUsuario;
    const rolOperador = await prisma.rol.findUniqueOrThrow({ where: { nombreRol: "operador" } });
    const operador = await prisma.usuario.create({
      data: { nombreUsuario: "Operador", correoUsuario: `${marca}-o@prueba.test`, contrasenaUsuario: "x", idRol: rolOperador.idRol },
    });
    idOperador = operador.idUsuario;
    idCategoria = (await prisma.categoria.findFirstOrThrow()).idCategoria;
    estado1 = (await prisma.estado.findUniqueOrThrow({ where: { ordenEstado: 1 } })).idEstado;
    estado2 = (await prisma.estado.findUniqueOrThrow({ where: { ordenEstado: 2 } })).idEstado;
  });

  afterAll(async () => {
    const reportes = await prisma.reporte.findMany({ where: { idUsuario }, select: { idReporte: true } });
    const ids = reportes.map((r) => r.idReporte);
    await prisma.historial.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.reporte.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.usuario.deleteMany({ where: { idUsuario: { in: [idUsuario, idOperador] } } });
    await prisma.$disconnect();
  });

  it("crear un reporte deja el reporte y su historial de creación", async () => {
    const reporte = await nuevoReporte();
    expect(reporte.estado.ordenEstado).toBe(1);
    expect(reporte.operador).toBeNull();
    const historial = await prisma.historial.findMany({ where: { idReporte: reporte.idReporte } });
    expect(historial).toHaveLength(1);
    expect(historial[0]).toMatchObject({ tipoHistorial: "creacion", idUsuario, idEstadoNuevo: estado1, idEstadoAnterior: null });
  });

  it("si falla el historial, el estado no cambia", async () => {
    const reporte = await nuevoReporte();

    // El historial se rechaza porque quien hace el cambio no existe
    await expect(
      cambiarEstadoReporte({
        idReporte: reporte.idReporte,
        idUsuario: USUARIO_INEXISTENTE,
        idEstadoActual: estado1,
        idEstadoNuevo: estado2,
      }),
    ).rejects.toThrow();

    const despues = await prisma.reporte.findUniqueOrThrow({ where: { idReporte: reporte.idReporte } });
    expect(despues.idEstado).toBe(estado1);
    expect(await filasHistorial(reporte.idReporte)).toBe(1); // solo la creación
  });

  it("si todo sale bien, el estado cambia y queda una fila de cambio_estado", async () => {
    const reporte = await nuevoReporte();
    const res = await cambiarEstadoReporte({
      idReporte: reporte.idReporte,
      idUsuario,
      idEstadoActual: estado1,
      idEstadoNuevo: estado2,
      descripcion: "Se revisó",
    });
    expect(res.actualizadas).toBe(1);
    expect(res.reporte?.estado.ordenEstado).toBe(2);
    const fila = await prisma.historial.findFirstOrThrow({
      where: { idReporte: reporte.idReporte, tipoHistorial: "cambio_estado" },
    });
    expect(fila).toMatchObject({ idEstadoAnterior: estado1, idEstadoNuevo: estado2, descripcionHistorial: "Se revisó" });
  });

  it("si el estado ya cambió, no pisa el cambio y no escribe historial", async () => {
    const reporte = await nuevoReporte();
    await cambiarEstadoReporte({ idReporte: reporte.idReporte, idUsuario, idEstadoActual: estado1, idEstadoNuevo: estado2 });
    const segundo = await cambiarEstadoReporte({
      idReporte: reporte.idReporte,
      idUsuario,
      idEstadoActual: estado1,
      idEstadoNuevo: estado2,
    });
    expect(segundo.actualizadas).toBe(0);
    expect(await filasHistorial(reporte.idReporte)).toBe(2); // creación + un solo cambio
  });

  it("si falla el historial al crear, no queda el reporte a medias", async () => {
    const titulo = `${marca}-sin-historial`;
    await expect(
      crearReporte({ idUsuario, titulo, descripcion: "d", idCategoria: 250, ubicacion: "u" }),
    ).rejects.toThrow();
    expect(await prisma.reporte.count({ where: { tituloReporte: titulo } })).toBe(0);
  });

  it("dos operadores a la vez: solo uno toma el reporte", async () => {
    const reporte = await nuevoReporte();
    const [a, b] = await Promise.all([
      asignarReporte({ idReporte: reporte.idReporte, idOperador: idUsuario }),
      asignarReporte({ idReporte: reporte.idReporte, idOperador: idUsuario }),
    ]);
    expect([a.actualizadas, b.actualizadas].sort()).toEqual([0, 1]);
    expect(await prisma.historial.count({ where: { idReporte: reporte.idReporte, tipoHistorial: "asignacion" } })).toBe(1);
  });

  it("cancelar: solo el dueño y solo en Reportado", async () => {
    const reporte = await nuevoReporte();

    expect((await cancelarReporte({ idReporte: reporte.idReporte, idUsuario: USUARIO_INEXISTENTE })).resultado).toBe("no_encontrado");

    const ok = await cancelarReporte({ idReporte: reporte.idReporte, idUsuario, razon: "Ya lo repararon" });
    expect(ok.resultado).toBe("ok");
    const cancelado = await prisma.reporte.findUniqueOrThrow({ where: { idReporte: reporte.idReporte } });
    expect(cancelado).toMatchObject({ canceladoReporte: true, razonCancelacionReporte: "Ya lo repararon" });

    // Cancelarlo otra vez ya no se puede
    expect((await cancelarReporte({ idReporte: reporte.idReporte, idUsuario })).resultado).toBe("no_editable");
    expect(await prisma.historial.count({ where: { idReporte: reporte.idReporte, tipoHistorial: "cancelacion" } })).toBe(1);

    // Uno que ya pasó a En análisis tampoco
    const enAnalisis = await nuevoReporte();
    await cambiarEstadoReporte({ idReporte: enAnalisis.idReporte, idUsuario, idEstadoActual: estado1, idEstadoNuevo: estado2 });
    expect((await cancelarReporte({ idReporte: enAnalisis.idReporte, idUsuario })).resultado).toBe("no_editable");
    const intacto = await prisma.reporte.findUniqueOrThrow({ where: { idReporte: enAnalisis.idReporte } });
    expect(intacto.canceladoReporte).toBe(false);
  });
  it("consultar el historial: en orden, con quien hizo cada movimiento, y solo para quien puede verlo", async () => {
    const reporte = await nuevoReporte();
    // Los tres movimientos caen en el mismo segundo: el orden lo decide el id
    await asignarReporte({ idReporte: reporte.idReporte, idOperador });
    await cambiarEstadoReporte({ idReporte: reporte.idReporte, idUsuario: idOperador, idEstadoActual: estado1, idEstadoNuevo: estado2, descripcion: "En revisión" });

    const historial = await consultarHistorial(reporte.idReporte, { idUsuario });
    expect(historial?.map((fila) => fila.tipoHistorial)).toEqual(["creacion", "asignacion", "cambio_estado"]);
    expect(historial?.map((fila) => fila.usuario)).toEqual([
      { idUsuario, nombreUsuario: "Prueba" },
      { idUsuario: idOperador, nombreUsuario: "Operador" },
      { idUsuario: idOperador, nombreUsuario: "Operador" },
    ]);
    expect(historial?.[2]).toMatchObject({
      estadoAnterior: { idEstado: estado1, ordenEstado: 1 },
      estadoNuevo: { idEstado: estado2, ordenEstado: 2 },
      descripcionHistorial: "En revisión",
    });

    // Otro usuario no lo ve (null, igual que si no existiera); el operador sí
    expect(await consultarHistorial(reporte.idReporte, { idUsuario: idOperador })).toBeNull();
    expect(await consultarHistorial(reporte.idReporte)).toHaveLength(3);
    expect(await consultarHistorial(USUARIO_INEXISTENTE)).toBeNull();
  });
});
