// Las contraseñas nunca se guardan en texto plano: solo el hash de bcrypt.
import bcrypt from "bcryptjs";

// Mismo costo que la semilla. El hash es lento a propósito para frenar ataques de fuerza bruta.
export const RONDAS_BCRYPT = 12;
export const LARGO_MINIMO = 8;
// bcrypt solo lee los primeros 72 bytes: más allá de eso dos contraseñas distintas darían el mismo hash
export const BYTES_MAXIMOS = 72;

// Devuelve el mensaje de error, o null si la contraseña es aceptable
export function validarContrasena(contrasena: unknown): string | null {
  if (typeof contrasena !== "string") return "La contraseña es obligatoria";
  if (contrasena.length < LARGO_MINIMO) return `La contraseña debe tener al menos ${LARGO_MINIMO} caracteres`;
  if (Buffer.byteLength(contrasena, "utf8") > BYTES_MAXIMOS) {
    return `La contraseña no puede pasar de ${BYTES_MAXIMOS} bytes`;
  }
  return null;
}

export function hashearContrasena(contrasena: string): Promise<string> {
  return bcrypt.hash(contrasena, RONDAS_BCRYPT);
}

export function verificarContrasena(contrasena: string, hash: string): Promise<boolean> {
  return bcrypt.compare(contrasena, hash);
}

// Hash de una contraseña inventada. El login lo compara cuando el correo no existe,
// para que tarde lo mismo que con un correo real y no se pueda adivinar qué correos hay.
export const HASH_FALSO = bcrypt.hashSync("contrasena-que-nadie-usa", RONDAS_BCRYPT);
