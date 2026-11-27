// Funciones de acceso a datos de usuarios. Están documentadas en docs/db-functions.md.
// Ninguna función pública devuelve el hash de la contraseña, salvo buscarUsuarioPorCorreo,
// que existe para que el login pueda compararlo.
import { prisma } from "./prisma";

export const ROL_USUARIO = "usuario";

// Campos que se pueden devolver a la API: nunca incluyen contrasenaUsuario
const seleccionPublica = {
  idUsuario: true,
  nombreUsuario: true,
  correoUsuario: true,
  creacionUsuario: true,
  rol: { select: { idRol: true, nombreRol: true } },
} as const;

export type UsuarioPublico = {
  idUsuario: number;
  nombreUsuario: string;
  correoUsuario: string;
  creacionUsuario: Date;
  rol: { idRol: number; nombreRol: string };
};

export type UsuarioConHash = UsuarioPublico & { contrasenaUsuario: string };

export class CorreoDuplicadoError extends Error {
  constructor() {
    super("Ya existe una cuenta con ese correo");
    this.name = "CorreoDuplicadoError";
  }
}

// El correo se guarda siempre en minúsculas y sin espacios, así "A@x.com" y "a@x.com" son el mismo
export function normalizarCorreo(correo: string): string {
  return correo.trim().toLowerCase();
}

function esErrorPrisma(error: unknown, codigo: string): boolean {
  return typeof error === "object" && error !== null && (error as { code?: unknown }).code === codigo;
}

// Crea una cuenta con rol "usuario". Los operadores salen de la semilla, nunca de aquí.
// El hash lo calcula quien llama (ver auth/contrasenas.ts); esta función no ve la contraseña real.
// Lanza CorreoDuplicadoError si el correo ya existe (UNIQUE en la BD).
export async function crearUsuario(datos: {
  nombre: string;
  correo: string;
  contrasenaHash: string;
}): Promise<UsuarioPublico> {
  const rol = await prisma.rol.findUniqueOrThrow({ where: { nombreRol: ROL_USUARIO } });
  try {
    return await prisma.usuario.create({
      data: {
        nombreUsuario: datos.nombre.trim(),
        correoUsuario: normalizarCorreo(datos.correo),
        contrasenaUsuario: datos.contrasenaHash,
        idRol: rol.idRol,
      },
      select: seleccionPublica,
    });
  } catch (error) {
    if (esErrorPrisma(error, "P2002")) throw new CorreoDuplicadoError();
    throw error;
  }
}

// Para el login: es la única que devuelve el hash. Devuelve null si el correo no existe.
export async function buscarUsuarioPorCorreo(correo: string): Promise<UsuarioConHash | null> {
  return prisma.usuario.findUnique({
    where: { correoUsuario: normalizarCorreo(correo) },
    select: { ...seleccionPublica, contrasenaUsuario: true },
  });
}

// Devuelve null si el id no existe
export async function buscarUsuarioPorId(idUsuario: number): Promise<UsuarioPublico | null> {
  return prisma.usuario.findUnique({ where: { idUsuario }, select: seleccionPublica });
}

// Actualiza el nombre, la contraseña (ya hasheada) o ambos. No toca el correo ni el rol.
// Devuelve el usuario actualizado, o null si el id no existe.
export async function actualizarUsuario(
  idUsuario: number,
  cambios: { nombre?: string; contrasenaHash?: string },
): Promise<UsuarioPublico | null> {
  const data: { nombreUsuario?: string; contrasenaUsuario?: string } = {};
  if (cambios.nombre !== undefined) data.nombreUsuario = cambios.nombre.trim();
  if (cambios.contrasenaHash !== undefined) data.contrasenaUsuario = cambios.contrasenaHash;
  if (Object.keys(data).length === 0) return buscarUsuarioPorId(idUsuario);

  try {
    return await prisma.usuario.update({ where: { idUsuario }, data, select: seleccionPublica });
  } catch (error) {
    if (esErrorPrisma(error, "P2025")) return null;
    throw error;
  }
}
