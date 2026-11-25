// Evidencias contra la BD REAL (#42): lo que un mock no puede probar, como la ruta UNIQUE,
// la llave foránea del reporte y el conteo con GROUP BY.
// Si la BD no está disponible se saltan solas, igual que historial.integracion.test.ts.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { contarEvidenciasPorTipo, guardarEvidencia, listarEvidencias, RutaDuplicadaError } from "../src/db/evidencias";
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
const marca = `prueba-evidencias-${Date.now()}`;
// Un id de reporte que no existe: la llave foránea lo rechaza
const REPORTE_INEXISTENTE = 4_000_000_000;

describe.skipIf(!disponible)("evidencias (BD real)", () => {
  let idCreador: number;
  let idOperador: number;
  let idCategoria: number;
  let rutas = 0;

  const nuevaRuta = () => `/uploads/${marca}-${++rutas}.jpg`;
  const nuevoReporte = () => crearReporte({ idUsuario: idCreador, titulo: marca, descripcion: "d", idCategoria, ubicacion: "u" });

  beforeAll(async () => {
    const [rolUsuario, rolOperador] = await Promise.all([
      prisma.rol.findUniqueOrThrow({ where: { nombreRol: "usuario" } }),
      prisma.rol.findUniqueOrThrow({ where: { nombreRol: "operador" } }),
    ]);
    const creador = await prisma.usuario.create({
      data: { nombreUsuario: "Creador", correoUsuario: `${marca}-c@prueba.test`, contrasenaUsuario: "x", idRol: rolUsuario.idRol },
    });
    const operador = await prisma.usuario.create({
      data: { nombreUsuario: "Operador", correoUsuario: `${marca}-o@prueba.test`, contrasenaUsuario: "x", idRol: rolOperador.idRol },
    });
    idCreador = creador.idUsuario;
    idOperador = operador.idUsuario;
    idCategoria = (await prisma.categoria.findFirstOrThrow()).idCategoria;
  });

  afterAll(async () => {
    const ids = (await prisma.reporte.findMany({ where: { idUsuario: idCreador }, select: { idReporte: true } })).map((r) => r.idReporte);
    await prisma.evidencia.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.historial.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.reporte.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.usuario.deleteMany({ where: { idUsuario: { in: [idCreador, idOperador] } } });
    await prisma.$disconnect();
  });

  it("guarda la evidencia con su tipo, su ruta y quien la subió", async () => {
    const reporte = await nuevoReporte();
    const ruta = nuevaRuta();
    const evidencia = await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta });

    expect(evidencia).toMatchObject({
      tipoEvidencia: "reporte",
      rutaEvidencia: ruta,
      usuario: { idUsuario: idCreador, nombreUsuario: "Creador" },
    });
    expect(evidencia.creacionEvidencia).toBeInstanceOf(Date);
    expect(evidencia).not.toHaveProperty("usuario.correoUsuario");
  });

  it("la misma ruta dos veces lanza RutaDuplicadaError y no guarda la segunda", async () => {
    const reporte = await nuevoReporte();
    const ruta = nuevaRuta();
    await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta });

    await expect(
      guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta }),
    ).rejects.toBeInstanceOf(RutaDuplicadaError);
    expect(await prisma.evidencia.count({ where: { rutaEvidencia: ruta } })).toBe(1);
  });

  it("si el reporte no existe la BD la rechaza", async () => {
    const ruta = nuevaRuta();
    await expect(
      guardarEvidencia({ idReporte: REPORTE_INEXISTENTE, idUsuario: idCreador, tipo: "reporte", ruta }),
    ).rejects.toThrow();
    expect(await prisma.evidencia.count({ where: { rutaEvidencia: ruta } })).toBe(0);
  });

  it("cuenta por tipo: sin fotos de atencion sale 0, y sube al guardar una", async () => {
    const reporte = await nuevoReporte();
    expect(await contarEvidenciasPorTipo(reporte.idReporte)).toEqual({ reporte: 0, atencion: 0 });

    await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta: nuevaRuta() });
    await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta: nuevaRuta() });
    expect(await contarEvidenciasPorTipo(reporte.idReporte)).toEqual({ reporte: 2, atencion: 0 });

    await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idOperador, tipo: "atencion", ruta: nuevaRuta() });
    expect(await contarEvidenciasPorTipo(reporte.idReporte)).toEqual({ reporte: 2, atencion: 1 });
  });

  it("el conteo es solo del reporte pedido", async () => {
    const conFotos = await nuevoReporte();
    const sinFotos = await nuevoReporte();
    await guardarEvidencia({ idReporte: conFotos.idReporte, idUsuario: idOperador, tipo: "atencion", ruta: nuevaRuta() });
    expect(await contarEvidenciasPorTipo(sinFotos.idReporte)).toEqual({ reporte: 0, atencion: 0 });
  });

  it("lista las de los dos tipos en el orden en que se subieron, aunque sean del mismo segundo", async () => {
    const reporte = await nuevoReporte();
    const primera = await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta: nuevaRuta() });
    const segunda = await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idOperador, tipo: "atencion", ruta: nuevaRuta() });
    const tercera = await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta: nuevaRuta() });

    const lista = await listarEvidencias(reporte.idReporte);
    expect(lista?.map((e) => e.idEvidencia)).toEqual([primera.idEvidencia, segunda.idEvidencia, tercera.idEvidencia]);
    expect(lista?.map((e) => e.usuario.idUsuario)).toEqual([idCreador, idOperador, idCreador]);
  });

  it("un usuario no ve las fotos del reporte de otro; el dueño y el operador sí", async () => {
    const reporte = await nuevoReporte();
    await guardarEvidencia({ idReporte: reporte.idReporte, idUsuario: idCreador, tipo: "reporte", ruta: nuevaRuta() });

    expect(await listarEvidencias(reporte.idReporte, { idUsuario: idOperador })).toBeNull();
    expect(await listarEvidencias(reporte.idReporte, { idUsuario: idCreador })).toHaveLength(1);
    expect(await listarEvidencias(reporte.idReporte)).toHaveLength(1);
    expect(await listarEvidencias(REPORTE_INEXISTENTE)).toBeNull();
  });
});
