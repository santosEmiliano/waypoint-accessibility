// Evidencias (fotos) de los reportes. Están documentadas en docs/db-functions.md.
// En la BD solo se guarda la ruta del archivo y sus datos, nunca la imagen.
// Son de solo inserción: una foto subida no se borra (docs/api.md).
import type { Prisma } from "../generated/prisma/client";
import { prisma } from "./prisma";

export type TipoEvidencia = "reporte" | "atencion";

export const TIPOS_EVIDENCIA: readonly TipoEvidencia[] = ["reporte", "atencion"];

// Largo de la columna ruta_evidencia (VARCHAR(500))
export const LARGO_MAXIMO_RUTA = 500;

// Lo que se devuelve de una evidencia: de quien la subió solo el id y el nombre
const seleccionEvidencia = {
  idEvidencia: true,
  tipoEvidencia: true,
  rutaEvidencia: true,
  creacionEvidencia: true,
  usuario: { select: { idUsuario: true, nombreUsuario: true } },
} as const;

export type Evidencia = Prisma.EvidenciaGetPayload<{ select: typeof seleccionEvidencia }>;

export type ConteoEvidencias = Record<TipoEvidencia, number>;

export type DatosEvidencia = {
  idReporte: number;
  // Quien subió la foto
  idUsuario: number;
  tipo: TipoEvidencia;
  // La ruta que la API va a responder, por ejemplo "/uploads/<uuid>.jpg"
  ruta: string;
};

// La ruta ya estaba guardada (es UNIQUE en la BD). Con nombres UUID no debería pasar.
export class RutaDuplicadaError extends Error {
  constructor() {
    super("Ya existe una evidencia con esa ruta");
    this.name = "RutaDuplicadaError";
  }
}

function esErrorPrisma(error: unknown, codigo: string): boolean {
  return typeof error === "object" && error !== null && (error as { code?: unknown }).code === codigo;
}

// Guarda los datos de una foto ya escrita en uploads/.
// No revisa quién puede subir ni en qué estado: eso lo decide la API antes (docs/api.md, #45).
// Lanza RutaDuplicadaError si la ruta ya existe, y el error de la BD si el reporte o el usuario
// no existen (llave foránea).
export async function guardarEvidencia(datos: DatosEvidencia): Promise<Evidencia> {
  const ruta = datos.ruta.trim();
  if (ruta === "" || ruta.length > LARGO_MAXIMO_RUTA) {
    throw new Error(`La ruta de la evidencia debe tener entre 1 y ${LARGO_MAXIMO_RUTA} caracteres`);
  }
  if (!TIPOS_EVIDENCIA.includes(datos.tipo)) {
    throw new Error(`Tipo de evidencia inválido: ${String(datos.tipo)}`);
  }

  try {
    return await prisma.evidencia.create({
      data: {
        idReporte: datos.idReporte,
        idUsuario: datos.idUsuario,
        tipoEvidencia: datos.tipo,
        rutaEvidencia: ruta,
      },
      select: seleccionEvidencia,
    });
  } catch (error) {
    if (esErrorPrisma(error, "P2002")) throw new RutaDuplicadaError();
    throw error;
  }
}

// Fotos de un reporte, de los dos tipos, de la más antigua a la más reciente.
// Con idUsuario (quien consulta es un `usuario`) solo responde si el reporte es suyo; si es de otro
// o no existe devuelve null, para que la API responda 404 sin revelar que existe.
// Sin idUsuario (el operador) busca entre todos los reportes.
export async function listarEvidencias(
  idReporte: number,
  { idUsuario }: { idUsuario?: number } = {},
): Promise<Evidencia[] | null> {
  const reporte = await prisma.reporte.findFirst({
    where: { idReporte, ...(idUsuario !== undefined && { idUsuario }) },
    select: { idReporte: true },
  });
  if (!reporte) return null;

  return prisma.evidencia.findMany({
    where: { idReporte },
    select: seleccionEvidencia,
    orderBy: [{ creacionEvidencia: "asc" }, { idEvidencia: "asc" }],
  });
}

// Cuántas fotos de cada tipo tiene un reporte. Siempre trae los dos tipos (0 si no hay).
// Es para la regla del sistema: para pasar a Resuelto hace falta al menos una de tipo `atencion`.
// No hay carrera con el cambio de estado: las fotos nunca se borran, así que el conteo solo sube.
export async function contarEvidenciasPorTipo(idReporte: number): Promise<ConteoEvidencias> {
  const grupos = await prisma.evidencia.groupBy({
    by: ["tipoEvidencia"],
    where: { idReporte },
    _count: { _all: true },
  });

  const conteo: ConteoEvidencias = { reporte: 0, atencion: 0 };
  for (const grupo of grupos) {
    conteo[grupo.tipoEvidencia] = grupo._count._all;
  }
  return conteo;
}
