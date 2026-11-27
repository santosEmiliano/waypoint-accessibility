import { beforeEach, describe, expect, it, vi } from "vitest";

// Se reemplaza el cliente de Prisma: así las pruebas no necesitan la BD levantada.
// $transaction ejecuta la función con el mismo objeto, como si fuera la transacción.
const prisma = vi.hoisted(() => {
  const cliente: Record<string, unknown> = {
    estado: { findUniqueOrThrow: vi.fn(), findMany: vi.fn() },
    reporte: {
      create: vi.fn(),
      findMany: vi.fn(),
      groupBy: vi.fn(),
      findFirst: vi.fn(),
      findUniqueOrThrow: vi.fn(),
      updateMany: vi.fn(),
    },
    historial: { create: vi.fn(), findMany: vi.fn() },
    categoria: { findMany: vi.fn() },
  };
  cliente.$transaction = vi.fn(async (funcion: (tx: unknown) => unknown) => funcion(cliente));
  return cliente as any;
});
vi.mock("../src/db/prisma", () => ({ prisma }));

import { listarCategorias, listarEstados } from "../src/db/categorias";
import { consultarHistorial, listarHistorial } from "../src/db/historial";
import {
  armarFiltros,
  asignarReporte,
  escaparLike,
  cambiarEstadoReporte,
  cancelarReporte,
  contarReportesPorEstado,
  crearReporte,
  listarReportes,
  obtenerReporte,
} from "../src/db/reportes";

const reporteDevuelto = { idReporte: 7 };

beforeEach(() => {
  vi.resetAllMocks();
  prisma.$transaction.mockImplementation(async (funcion: (tx: unknown) => unknown) => funcion(prisma));
  prisma.reporte.findUniqueOrThrow.mockResolvedValue(reporteDevuelto);
});

describe("crearReporte", () => {
  const datos = {
    idUsuario: 5,
    titulo: "  Rampa rota ",
    descripcion: " Tiene una grieta ",
    idCategoria: 1,
    ubicacion: " Edificio 1 ",
  };

  it("nace en el estado de orden 1 y escribe el historial de creación en la misma transacción", async () => {
    prisma.estado.findUniqueOrThrow.mockResolvedValue({ idEstado: 9 });
    prisma.reporte.create.mockResolvedValue({ idReporte: 7 });
    await crearReporte(datos);

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.estado.findUniqueOrThrow).toHaveBeenCalledWith({ where: { ordenEstado: 1 } });
    expect(prisma.reporte.create.mock.calls[0][0].data).toMatchObject({
      idUsuario: 5,
      idEstado: 9,
      tituloReporte: "Rampa rota",
      descripcionReporte: "Tiene una grieta",
      ubicacionReporte: "Edificio 1",
      latitudReporte: null,
      longitudReporte: null,
    });
    expect(prisma.historial.create.mock.calls[0][0].data).toMatchObject({
      idReporte: 7,
      idUsuario: 5,
      tipoHistorial: "creacion",
      idEstadoAnterior: null,
      idEstadoNuevo: 9,
    });
  });

  it("rechaza la latitud sin la longitud, y al revés, sin escribir nada", async () => {
    await expect(crearReporte({ ...datos, latitud: 21.9 })).rejects.toThrow(/van juntas/);
    await expect(crearReporte({ ...datos, longitud: -102.3 })).rejects.toThrow(/van juntas/);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it("acepta las dos coordenadas", async () => {
    prisma.estado.findUniqueOrThrow.mockResolvedValue({ idEstado: 1 });
    prisma.reporte.create.mockResolvedValue({ idReporte: 7 });
    await crearReporte({ ...datos, latitud: 21.91356, longitud: -102.31502 });
    expect(prisma.reporte.create.mock.calls[0][0].data).toMatchObject({ latitudReporte: 21.91356, longitudReporte: -102.31502 });
  });

  it("si el historial falla, el error sale (la transacción se deshace)", async () => {
    prisma.estado.findUniqueOrThrow.mockResolvedValue({ idEstado: 1 });
    prisma.reporte.create.mockResolvedValue({ idReporte: 7 });
    const fallo = new Error("falló el historial");
    prisma.historial.create.mockRejectedValue(fallo);
    await expect(crearReporte(datos)).rejects.toBe(fallo);
  });
});

describe("armarFiltros", () => {
  it("sin filtros excluye los cancelados", () => {
    expect(armarFiltros({})).toEqual({ canceladoReporte: false });
  });

  it("cancelados: true devuelve solo los cancelados", () => {
    expect(armarFiltros({ cancelados: true })).toEqual({ canceladoReporte: true });
  });

  it("los filtros se combinan todos a la vez", () => {
    const where = armarFiltros({ idUsuario: 5, idEstado: 2, idCategoria: 3, texto: "rampa" });
    expect(where).toMatchObject({ canceladoReporte: false, idUsuario: 5, idEstado: 2, idCategoria: 3 });
    expect(where.OR).toEqual([
      { tituloReporte: { contains: "rampa" } },
      { descripcionReporte: { contains: "rampa" } },
      { ubicacionReporte: { contains: "rampa" } },
    ]);
  });

  it("el texto se recorta y uno vacío no filtra", () => {
    expect(armarFiltros({ texto: "  rampa " }).OR).toHaveLength(3);
    expect(armarFiltros({ texto: "   " })).toEqual({ canceladoReporte: false });
  });

  it("escapa los comodines de LIKE para que se busquen como texto", () => {
    expect(escaparLike("100%")).toBe(String.raw`100\%`);
    expect(escaparLike("a_b")).toBe(String.raw`a\_b`);
    expect(escaparLike(String.raw`C:\ruta`)).toBe(String.raw`C:\\ruta`);
    expect(escaparLike("rampa")).toBe("rampa");
    expect(armarFiltros({ texto: "50%" }).OR).toContainEqual({ tituloReporte: { contains: String.raw`50\%` } });
  });

  it("un id 0 sí cuenta como filtro", () => {
    expect(armarFiltros({ idEstado: 0 })).toMatchObject({ idEstado: 0 });
  });
});

describe("listarReportes y obtenerReporte", () => {
  it("lista los más recientes primero", async () => {
    prisma.reporte.findMany.mockResolvedValue([]);
    await listarReportes({ idUsuario: 5 });
    const llamada = prisma.reporte.findMany.mock.calls[0][0];
    expect(llamada.where).toMatchObject({ idUsuario: 5, canceladoReporte: false });
    expect(llamada.orderBy[0]).toEqual({ creacionReporte: "desc" });
  });

  it("nunca pide el correo de las personas", async () => {
    prisma.reporte.findMany.mockResolvedValue([]);
    await listarReportes();
    const { usuario, operador } = prisma.reporte.findMany.mock.calls[0][0].select;
    expect(usuario.select).toEqual({ idUsuario: true, nombreUsuario: true });
    expect(operador.select).toEqual({ idUsuario: true, nombreUsuario: true });
  });

  it("el detalle de un usuario solo busca entre sus reportes", async () => {
    prisma.reporte.findFirst.mockResolvedValue(null);
    expect(await obtenerReporte(7, { idUsuario: 5 })).toBeNull();
    expect(prisma.reporte.findFirst.mock.calls[0][0].where).toEqual({ idReporte: 7, idUsuario: 5 });
  });

  it("el detalle de un operador no filtra por dueño", async () => {
    prisma.reporte.findFirst.mockResolvedValue(reporteDevuelto);
    await obtenerReporte(7);
    expect(prisma.reporte.findFirst.mock.calls[0][0].where).toEqual({ idReporte: 7 });
  });
});

describe("paginación del listado", () => {
  const llamada = () => prisma.reporte.findMany.mock.calls[0][0];

  beforeEach(() => {
    prisma.reporte.findMany.mockResolvedValue([]);
  });

  it("sin página devuelve todos, por fecha de creación y con desempate por id", async () => {
    await listarReportes();
    expect(llamada().orderBy).toEqual([{ creacionReporte: "desc" }, { idReporte: "desc" }]);
    expect(llamada()).not.toHaveProperty("take");
    expect(llamada()).not.toHaveProperty("skip");
  });

  it("limite y desde se vuelven take y skip, junto con los filtros", async () => {
    await listarReportes({ idUsuario: 5 }, { limite: 10, desde: 20 });
    expect(llamada()).toMatchObject({ take: 10, skip: 20, where: { idUsuario: 5, canceladoReporte: false } });
  });

  it("desde 0 es la primera página", async () => {
    await listarReportes({}, { limite: 10, desde: 0 });
    expect(llamada()).toMatchObject({ take: 10, skip: 0 });
  });

  it("orden por actualización: los que cambiaron más recientemente primero, también con desempate", async () => {
    await listarReportes({}, { orden: "actualizacion" });
    expect(llamada().orderBy).toEqual([{ actualizacionReporte: "desc" }, { idReporte: "desc" }]);
  });
});

describe("contarReportesPorEstado", () => {
  const estados = [{ idEstado: 1 }, { idEstado: 2 }, { idEstado: 3 }, { idEstado: 4 }];

  beforeEach(() => {
    prisma.estado.findMany.mockResolvedValue(estados);
  });

  it("devuelve los 4 estados en orden, con 0 en los que no tienen reportes", async () => {
    prisma.reporte.groupBy.mockResolvedValue([
      { idEstado: 3, _count: { _all: 5 } },
      { idEstado: 1, _count: { _all: 2 } },
    ]);
    expect(await contarReportesPorEstado()).toEqual([
      { idEstado: 1, total: 2 },
      { idEstado: 2, total: 0 },
      { idEstado: 3, total: 5 },
      { idEstado: 4, total: 0 },
    ]);
    expect(prisma.estado.findMany.mock.calls[0][0].orderBy).toEqual({ ordenEstado: "asc" });
  });

  it("agrupa por estado en una sola consulta, sin los cancelados y con los filtros del listado", async () => {
    prisma.reporte.groupBy.mockResolvedValue([]);
    await contarReportesPorEstado({ idUsuario: 5, idCategoria: 2, texto: "rampa" });
    const consulta = prisma.reporte.groupBy.mock.calls[0][0];
    expect(prisma.reporte.groupBy).toHaveBeenCalledTimes(1);
    expect(consulta.by).toEqual(["idEstado"]);
    expect(consulta.where).toMatchObject({ canceladoReporte: false, idUsuario: 5, idCategoria: 2 });
    expect(consulta.where.OR).toHaveLength(3);
  });

  it("no acepta filtrar por estado ni contar cancelados aunque se los pasen", async () => {
    prisma.reporte.groupBy.mockResolvedValue([]);
    await contarReportesPorEstado({ idEstado: 2, cancelados: true } as never);
    expect(prisma.reporte.groupBy.mock.calls[0][0].where).toEqual({ canceladoReporte: false });
  });

  it("sin reportes, los 4 estados en 0", async () => {
    prisma.reporte.groupBy.mockResolvedValue([]);
    expect((await contarReportesPorEstado()).map((e) => e.total)).toEqual([0, 0, 0, 0]);
  });
});

describe("cancelarReporte", () => {
  it("cancela solo si es del usuario, está en Reportado y no estaba cancelado (todo en el WHERE)", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 1 });
    const res = await cancelarReporte({ idReporte: 7, idUsuario: 5, razon: " Ya lo repararon " });
    expect(res).toEqual({ resultado: "ok", reporte: reporteDevuelto });
    const llamada = prisma.reporte.updateMany.mock.calls[0][0];
    expect(llamada.where).toEqual({
      idReporte: 7,
      idUsuario: 5,
      canceladoReporte: false,
      estado: { ordenEstado: 1 },
    });
    expect(llamada.data).toEqual({ canceladoReporte: true, razonCancelacionReporte: "Ya lo repararon" });
    expect(prisma.historial.create.mock.calls[0][0].data).toMatchObject({ tipoHistorial: "cancelacion", idUsuario: 5, idReporte: 7 });
  });

  it("sin razón guarda null", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 1 });
    await cancelarReporte({ idReporte: 7, idUsuario: 5 });
    expect(prisma.reporte.updateMany.mock.calls[0][0].data.razonCancelacionReporte).toBeNull();
  });

  it("si es suyo pero ya no está en Reportado responde no_editable y no escribe historial", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 0 });
    prisma.reporte.findFirst.mockResolvedValue({ idReporte: 7 });
    expect(await cancelarReporte({ idReporte: 7, idUsuario: 5 })).toEqual({ resultado: "no_editable" });
    expect(prisma.historial.create).not.toHaveBeenCalled();
  });

  it("si es de otro usuario o no existe responde no_encontrado, sin distinguirlos", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 0 });
    prisma.reporte.findFirst.mockResolvedValue(null);
    expect(await cancelarReporte({ idReporte: 7, idUsuario: 99 })).toEqual({ resultado: "no_encontrado" });
    expect(prisma.historial.create).not.toHaveBeenCalled();
  });
});

describe("asignarReporte", () => {
  it("toma el reporte solo si nadie lo tenía, y escribe el historial de asignación", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 1 });
    const res = await asignarReporte({ idReporte: 7, idOperador: 12 });
    expect(res.actualizadas).toBe(1);
    const llamada = prisma.reporte.updateMany.mock.calls[0][0];
    expect(llamada.where).toMatchObject({ idReporte: 7, idOperador: null, canceladoReporte: false });
    expect(llamada.data).toEqual({ idOperador: 12 });
    expect(prisma.historial.create.mock.calls[0][0].data).toMatchObject({ tipoHistorial: "asignacion", idUsuario: 12 });
  });

  it("si otro operador llegó primero devuelve 0 filas y no escribe historial", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 0 });
    expect(await asignarReporte({ idReporte: 7, idOperador: 12 })).toEqual({ actualizadas: 0, reporte: null });
    expect(prisma.historial.create).not.toHaveBeenCalled();
  });
});

describe("cambiarEstadoReporte", () => {
  const datos = { idReporte: 7, idUsuario: 12, idEstadoActual: 1, idEstadoNuevo: 2, descripcion: " Se revisó " };

  it("lleva el estado actual en el WHERE y escribe el historial con los dos estados", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 1 });
    const res = await cambiarEstadoReporte(datos);
    expect(res.actualizadas).toBe(1);
    const llamada = prisma.reporte.updateMany.mock.calls[0][0];
    expect(llamada.where).toEqual({ idReporte: 7, idEstado: 1, canceladoReporte: false });
    expect(llamada.data).toEqual({ idEstado: 2 });
    expect(prisma.historial.create.mock.calls[0][0].data).toMatchObject({
      tipoHistorial: "cambio_estado",
      idUsuario: 12,
      idEstadoAnterior: 1,
      idEstadoNuevo: 2,
      descripcionHistorial: "Se revisó",
    });
  });

  it("si el estado ya cambió devuelve 0 filas y no escribe historial", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 0 });
    expect(await cambiarEstadoReporte(datos)).toEqual({ actualizadas: 0, reporte: null });
    expect(prisma.historial.create).not.toHaveBeenCalled();
  });

  it("si el historial falla, el error sale para que la transacción se deshaga", async () => {
    prisma.reporte.updateMany.mockResolvedValue({ count: 1 });
    const fallo = new Error("falló el historial");
    prisma.historial.create.mockRejectedValue(fallo);
    await expect(cambiarEstadoReporte(datos)).rejects.toBe(fallo);
  });
});

describe("catálogos e historial", () => {
  it("las categorías salen en orden alfabético", async () => {
    prisma.categoria.findMany.mockResolvedValue([]);
    await listarCategorias();
    expect(prisma.categoria.findMany.mock.calls[0][0].orderBy).toEqual({ nombreCategoria: "asc" });
  });

  it("los estados salen por su orden, no por su id", async () => {
    prisma.estado.findMany = vi.fn().mockResolvedValue([]);
    await listarEstados();
    expect(prisma.estado.findMany.mock.calls[0][0].orderBy).toEqual({ ordenEstado: "asc" });
  });

  it("el historial sale de lo más antiguo a lo más reciente", async () => {
    prisma.historial.findMany.mockResolvedValue([]);
    await listarHistorial(7);
    const llamada = prisma.historial.findMany.mock.calls[0][0];
    expect(llamada.where).toEqual({ idReporte: 7 });
    expect(llamada.orderBy).toEqual([{ creacionHistorial: "asc" }, { idHistorial: "asc" }]);
  });

  it("cada fila del historial trae a quien hizo el movimiento (id y nombre, sin correo)", async () => {
    prisma.historial.findMany.mockResolvedValue([]);
    await listarHistorial(7);
    const select = prisma.historial.findMany.mock.calls[0][0].select;
    expect(select.usuario).toEqual({ select: { idUsuario: true, nombreUsuario: true } });
    expect(select.estadoAnterior).toBeDefined();
    expect(select.estadoNuevo).toBeDefined();
  });
});

describe("consultarHistorial", () => {
  it("un usuario solo ve el historial de sus reportes", async () => {
    prisma.reporte.findFirst.mockResolvedValue({ idReporte: 7 });
    prisma.historial.findMany.mockResolvedValue([{ idHistorial: 1 }]);
    const historial = await consultarHistorial(7, { idUsuario: 5 });

    expect(prisma.reporte.findFirst.mock.calls[0][0].where).toEqual({ idReporte: 7, idUsuario: 5 });
    expect(historial).toEqual([{ idHistorial: 1 }]);
  });

  it("el reporte de otro usuario responde null, igual que uno que no existe, y no lee el historial", async () => {
    prisma.reporte.findFirst.mockResolvedValue(null);
    expect(await consultarHistorial(7, { idUsuario: 99 })).toBeNull();
    expect(prisma.historial.findMany).not.toHaveBeenCalled();
  });

  it("sin idUsuario (el operador) busca entre todos los reportes", async () => {
    prisma.reporte.findFirst.mockResolvedValue({ idReporte: 7 });
    prisma.historial.findMany.mockResolvedValue([]);
    expect(await consultarHistorial(7)).toEqual([]);
    expect(prisma.reporte.findFirst.mock.calls[0][0].where).toEqual({ idReporte: 7 });
  });
});
