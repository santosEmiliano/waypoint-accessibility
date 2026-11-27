// Funciones de acceso a datos de reportes. Están documentadas en docs/db-functions.md.
// Toda función que cambia un reporte escribe su historial en la MISMA transacción:
// o se guardan los dos, o no se guarda ninguno.
import type { Prisma } from "../generated/prisma/client";
import { registrarHistorial } from "./historial";
import { prisma } from "./prisma";

export const ORDEN_ESTADO_INICIAL = 1;
export const ORDEN_ESTADO_FINAL = 4;

// Lo que se devuelve de un reporte: la categoría, el estado, el creador y el operador vienen
// como objetos, y de las personas solo el id y el nombre (nunca el correo).
const seleccionReporte = {
  idReporte: true,
  tituloReporte: true,
  descripcionReporte: true,
  ubicacionReporte: true,
  latitudReporte: true,
  longitudReporte: true,
  canceladoReporte: true,
  razonCancelacionReporte: true,
  creacionReporte: true,
  actualizacionReporte: true,
  categoria: { select: { idCategoria: true, nombreCategoria: true } },
  estado: { select: { idEstado: true, nombreEstado: true, ordenEstado: true } },
  usuario: { select: { idUsuario: true, nombreUsuario: true } },
  operador: { select: { idUsuario: true, nombreUsuario: true } },
} as const;

// La latitud y la longitud salen como Decimal de Prisma: la API las convierte con Number()
export type Reporte = Prisma.ReporteGetPayload<{ select: typeof seleccionReporte }>;

export type DatosReporte = {
  idUsuario: number;
  titulo: string;
  descripcion: string;
  idCategoria: number;
  ubicacion: string;
  latitud?: number | null;
  longitud?: number | null;
};

// Crea el reporte en el estado con orden 1 (Reportado) y escribe el historial `creacion`.
// Lanza Error si viene solo la latitud o solo la longitud, y el error de la BD si la categoría
// o el usuario no existen (llave foránea).
export async function crearReporte(datos: DatosReporte): Promise<Reporte> {
  const hayLatitud = datos.latitud !== undefined && datos.latitud !== null;
  const hayLongitud = datos.longitud !== undefined && datos.longitud !== null;
  if (hayLatitud !== hayLongitud) {
    throw new Error("La latitud y la longitud van juntas: o vienen las dos o ninguna");
  }

  return prisma.$transaction(async (tx) => {
    const estadoInicial = await tx.estado.findUniqueOrThrow({ where: { ordenEstado: ORDEN_ESTADO_INICIAL } });
    const creado = await tx.reporte.create({
      data: {
        idUsuario: datos.idUsuario,
        idCategoria: datos.idCategoria,
        idEstado: estadoInicial.idEstado,
        tituloReporte: datos.titulo.trim(),
        descripcionReporte: datos.descripcion.trim(),
        ubicacionReporte: datos.ubicacion.trim(),
        latitudReporte: datos.latitud ?? null,
        longitudReporte: datos.longitud ?? null,
      },
      select: { idReporte: true },
    });
    await registrarHistorial(tx, {
      idReporte: creado.idReporte,
      idUsuario: datos.idUsuario,
      tipo: "creacion",
      idEstadoNuevo: estadoInicial.idEstado,
    });
    return tx.reporte.findUniqueOrThrow({ where: { idReporte: creado.idReporte }, select: seleccionReporte });
  });
}

export type FiltrosReportes = {
  // Solo los reportes de este usuario. Sin él devuelve los de todos (para el operador)
  idUsuario?: number;
  idEstado?: number;
  idCategoria?: number;
  // Texto que aparezca en el título, la descripción o la ubicación (sin importar mayúsculas)
  texto?: string;
  // true: solo los cancelados. Si no se manda, los cancelados no aparecen
  cancelados?: boolean;
};

// Prisma convierte `contains` en un LIKE '%texto%' pero no escapa los comodines del texto: sin esto,
// buscar "%" devolvería todos los reportes y "_" cualquier carácter. Se escapa primero la diagonal
// invertida, que es el carácter de escape de LIKE en MySQL.
export function escaparLike(texto: string): string {
  return texto.replace(/[\\%_]/g, (caracter) => `\\${caracter}`);
}

// Arma el WHERE. Cada filtro que se manda se suma a los demás (AND), así que son combinables.
export function armarFiltros(filtros: FiltrosReportes): Prisma.ReporteWhereInput {
  const where: Prisma.ReporteWhereInput = { canceladoReporte: filtros.cancelados === true };
  if (filtros.idUsuario !== undefined) where.idUsuario = filtros.idUsuario;
  if (filtros.idEstado !== undefined) where.idEstado = filtros.idEstado;
  if (filtros.idCategoria !== undefined) where.idCategoria = filtros.idCategoria;
  const texto = filtros.texto?.trim();
  if (texto) {
    const patron = escaparLike(texto);
    where.OR = [
      { tituloReporte: { contains: patron } },
      { descripcionReporte: { contains: patron } },
      { ubicacionReporte: { contains: patron } },
    ];
  }
  return where;
}

// Lista los reportes que cumplan todos los filtros, los más recientes primero.
export async function listarReportes(filtros: FiltrosReportes = {}): Promise<Reporte[]> {
  return prisma.reporte.findMany({
    where: armarFiltros(filtros),
    select: seleccionReporte,
    orderBy: [{ creacionReporte: "desc" }, { idReporte: "desc" }],
  });
}

// Detalle de un reporte, cancelado o no. Si se pasa idUsuario solo lo devuelve cuando es suyo:
// el reporte de otro usuario responde null, igual que uno que no existe (la API responde 404).
export async function obtenerReporte(idReporte: number, opciones: { idUsuario?: number } = {}): Promise<Reporte | null> {
  return prisma.reporte.findFirst({
    where: { idReporte, ...(opciones.idUsuario !== undefined && { idUsuario: opciones.idUsuario }) },
    select: seleccionReporte,
  });
}

export type ResultadoCancelar =
  | { resultado: "ok"; reporte: Reporte }
  // No existe, o es de otro usuario
  | { resultado: "no_encontrado" }
  // Es suyo, pero ya no está en Reportado o ya estaba cancelado
  | { resultado: "no_editable" };

// Cancela el reporte: solo el dueño y solo mientras está en Reportado. No se borra: queda marcado
// como cancelado, con la razón si se mandó, y se escribe el historial `cancelacion`.
// Las condiciones van en el WHERE del UPDATE, así que si un operador lo pasa a otro estado justo
// antes, no se cancela.
export async function cancelarReporte(datos: {
  idReporte: number;
  idUsuario: number;
  razon?: string | null;
}): Promise<ResultadoCancelar> {
  return prisma.$transaction(async (tx) => {
    const { count } = await tx.reporte.updateMany({
      where: {
        idReporte: datos.idReporte,
        idUsuario: datos.idUsuario,
        canceladoReporte: false,
        estado: { ordenEstado: ORDEN_ESTADO_INICIAL },
      },
      data: { canceladoReporte: true, razonCancelacionReporte: datos.razon?.trim() || null },
    });

    if (count === 0) {
      const esSuyo = await tx.reporte.findFirst({
        where: { idReporte: datos.idReporte, idUsuario: datos.idUsuario },
        select: { idReporte: true },
      });
      return esSuyo ? { resultado: "no_editable" } : { resultado: "no_encontrado" };
    }

    await registrarHistorial(tx, { idReporte: datos.idReporte, idUsuario: datos.idUsuario, tipo: "cancelacion" });
    const reporte = await tx.reporte.findUniqueOrThrow({ where: { idReporte: datos.idReporte }, select: seleccionReporte });
    return { resultado: "ok", reporte };
  });
}

export type ResultadoCambio = { actualizadas: number; reporte: Reporte | null };

// El operador toma el reporte, y solo si nadie lo había tomado, no está cancelado y no está Resuelto.
// `actualizadas` es 1 si lo tomó y 0 si no se pudo (otro operador llegó primero, o ya no se puede);
// la API distingue el motivo con obtenerReporte. Escribe el historial `asignacion`.
export async function asignarReporte(datos: { idReporte: number; idOperador: number }): Promise<ResultadoCambio> {
  return prisma.$transaction(async (tx) => {
    const { count } = await tx.reporte.updateMany({
      where: {
        idReporte: datos.idReporte,
        idOperador: null,
        canceladoReporte: false,
        estado: { ordenEstado: { lt: ORDEN_ESTADO_FINAL } },
      },
      data: { idOperador: datos.idOperador },
    });
    if (count === 0) return { actualizadas: 0, reporte: null };

    await registrarHistorial(tx, { idReporte: datos.idReporte, idUsuario: datos.idOperador, tipo: "asignacion" });
    const reporte = await tx.reporte.findUniqueOrThrow({ where: { idReporte: datos.idReporte }, select: seleccionReporte });
    return { actualizadas: 1, reporte };
  });
}

// Cambia el estado y escribe el historial `cambio_estado` en la misma transacción.
// La condición `id_estado = idEstadoActual` va en el WHERE del UPDATE: si alguien ya lo movió,
// no se pisa su cambio y `actualizadas` es 0 (la API responde 409 ESTADO_DESACTUALIZADO).
// Esta función NO valida que la transición sea la siguiente (orden + 1) ni que exista la foto de
// atención para Resuelto: eso lo valida la API antes de llamarla (docs/api.md).
// Si el historial no se puede escribir (por ejemplo, el usuario no existe) lanza el error y el
// estado queda como estaba.
export async function cambiarEstadoReporte(datos: {
  idReporte: number;
  // Quien hace el cambio, para el historial
  idUsuario: number;
  idEstadoActual: number;
  idEstadoNuevo: number;
  descripcion?: string | null;
}): Promise<ResultadoCambio> {
  return prisma.$transaction(async (tx) => {
    const { count } = await tx.reporte.updateMany({
      where: { idReporte: datos.idReporte, idEstado: datos.idEstadoActual, canceladoReporte: false },
      data: { idEstado: datos.idEstadoNuevo },
    });
    if (count === 0) return { actualizadas: 0, reporte: null };

    await registrarHistorial(tx, {
      idReporte: datos.idReporte,
      idUsuario: datos.idUsuario,
      tipo: "cambio_estado",
      idEstadoAnterior: datos.idEstadoActual,
      idEstadoNuevo: datos.idEstadoNuevo,
      descripcion: datos.descripcion?.trim() || null,
    });
    const reporte = await tx.reporte.findUniqueOrThrow({ where: { idReporte: datos.idReporte }, select: seleccionReporte });
    return { actualizadas: 1, reporte };
  });
}
