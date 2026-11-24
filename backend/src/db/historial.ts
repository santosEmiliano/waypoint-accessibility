// Historial de los reportes. Está documentado en docs/db-functions.md.
// Es de solo inserción: no hay funciones para editar ni borrar filas.
import { Prisma } from "../generated/prisma/client";
import { prisma } from "./prisma";

// El cliente que recibe una función dentro de prisma.$transaction(...)
export type Transaccion = Prisma.TransactionClient;

export type TipoHistorial =
  | "creacion"
  | "edicion"
  | "asignacion"
  | "cambio_estado"
  | "accion_correctiva"
  | "cancelacion";

export type EntradaHistorial = {
  idReporte: number;
  // Quien hizo el movimiento
  idUsuario: number;
  tipo: TipoHistorial;
  idEstadoAnterior?: number | null;
  idEstadoNuevo?: number | null;
  descripcion?: string | null;
};

// Escribe una fila del historial usando la transacción de quien llama.
// Por eso NO usa el cliente global: si el cambio y su historial no van en la misma transacción,
// uno puede guardarse sin el otro. Si esta inserción falla, también se deshace el cambio.
export async function registrarHistorial(tx: Transaccion, entrada: EntradaHistorial) {
  return tx.historial.create({
    data: {
      idReporte: entrada.idReporte,
      idUsuario: entrada.idUsuario,
      tipoHistorial: entrada.tipo,
      idEstadoAnterior: entrada.idEstadoAnterior ?? null,
      idEstadoNuevo: entrada.idEstadoNuevo ?? null,
      descripcionHistorial: entrada.descripcion ?? null,
    },
    select: seleccionHistorial,
  });
}

const seleccionHistorial = {
  idHistorial: true,
  tipoHistorial: true,
  descripcionHistorial: true,
  creacionHistorial: true,
  estadoAnterior: { select: { idEstado: true, nombreEstado: true, ordenEstado: true } },
  estadoNuevo: { select: { idEstado: true, nombreEstado: true, ordenEstado: true } },
  usuario: { select: { idUsuario: true, nombreUsuario: true } },
} as const;

// Línea de tiempo de un reporte, de lo más antiguo a lo más reciente.
// No revisa de quién es el reporte: eso lo decide la API con obtenerReporte.
export async function listarHistorial(idReporte: number) {
  return prisma.historial.findMany({
    where: { idReporte },
    select: seleccionHistorial,
    orderBy: [{ creacionHistorial: "asc" }, { idHistorial: "asc" }],
  });
}
