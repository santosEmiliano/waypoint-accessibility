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

export type FilaHistorial = Prisma.HistorialGetPayload<{ select: typeof seleccionHistorial }>;

// Línea de tiempo de un reporte, de lo más antiguo a lo más reciente, con quien hizo cada movimiento.
// La fecha se guarda sin milisegundos: dos movimientos del mismo segundo se ordenan por su id,
// que es el orden en que se escribieron.
// No revisa de quién es el reporte: para eso está consultarHistorial.
export async function listarHistorial(idReporte: number): Promise<FilaHistorial[]> {
  return prisma.historial.findMany({
    where: { idReporte },
    select: seleccionHistorial,
    orderBy: [{ creacionHistorial: "asc" }, { idHistorial: "asc" }],
  });
}

// Para GET /reportes/:id/historial: revisa que el reporte se pueda ver y devuelve su línea de tiempo.
// Con idUsuario (quien consulta es un `usuario`) solo responde si el reporte es suyo; si es de otro
// o no existe devuelve null, para que la API responda 404 sin revelar que existe.
// Sin idUsuario (el operador) busca entre todos los reportes.
export async function consultarHistorial(
  idReporte: number,
  { idUsuario }: { idUsuario?: number } = {},
): Promise<FilaHistorial[] | null> {
  const reporte = await prisma.reporte.findFirst({
    where: { idReporte, ...(idUsuario !== undefined && { idUsuario }) },
    select: { idReporte: true },
  });
  if (!reporte) return null;
  return listarHistorial(idReporte);
}
