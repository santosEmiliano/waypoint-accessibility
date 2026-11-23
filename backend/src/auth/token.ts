// Token de sesión: un JWT firmado con JWT_SECRET que vence a las JWT_EXPIRES_IN (8h por defecto).
// Solo lleva el id del usuario (sub) y el id de la sesión (jti); el rol y los demás datos se leen de la BD
// en cada petición, así un cambio de rol surte efecto sin esperar a que el token venza.
import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import type { AlmacenSesiones } from "./sesiones";

const POR_DEFECTO = "8h";

function leerSecreto(): string {
  const secreto = process.env.JWT_SECRET;
  if (!secreto || secreto.length < 16) {
    throw new Error("JWT_SECRET falta o es demasiado corto (mínimo 16 caracteres)");
  }
  return secreto;
}

export type DatosToken = { idUsuario: number; idSesion: string };

// Crea el token y registra su sesión. Devuelve el token que se manda a la app.
export async function emitirToken(almacen: AlmacenSesiones, idUsuario: number): Promise<string> {
  const idSesion = randomUUID();
  const vigencia = process.env.JWT_EXPIRES_IN || POR_DEFECTO;
  // HS256 fijo: nunca se acepta el algoritmo que declare el propio token
  const token = jwt.sign({}, leerSecreto(), {
    algorithm: "HS256",
    subject: String(idUsuario),
    jwtid: idSesion,
    expiresIn: vigencia as jwt.SignOptions["expiresIn"],
  });
  const { exp, iat } = jwt.decode(token) as { exp: number; iat: number };
  await almacen.guardar(idSesion, idUsuario, exp - iat);
  return token;
}

// Devuelve los datos del token, o null si es inválido, está alterado o ya venció
export function leerToken(token: string): DatosToken | null {
  try {
    const carga = jwt.verify(token, leerSecreto(), { algorithms: ["HS256"] });
    if (typeof carga === "string" || !carga.jti || !carga.sub) return null;
    const idUsuario = Number(carga.sub);
    if (!Number.isInteger(idUsuario) || idUsuario <= 0) return null;
    return { idUsuario, idSesion: carga.jti };
  } catch (error) {
    // Un secreto mal configurado es un fallo del servidor, no un token malo
    if (error instanceof jwt.JsonWebTokenError || error instanceof jwt.TokenExpiredError) return null;
    throw error;
  }
}

// Cierra la sesión del token. Si el token ya no era válido no hace nada (el logout igual responde 204).
export async function cerrarSesion(almacen: AlmacenSesiones, token: string): Promise<void> {
  const datos = leerToken(token);
  if (datos) await almacen.borrar(datos.idSesion);
}
