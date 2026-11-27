// Limpieza del texto que llega a la API (#35). Está documentada en docs/validacion-sanitizacion.md.
//
// La sanitización no reemplaza a las consultas parametrizadas: la defensa contra la inyección SQL
// es que todas las consultas pasan por Prisma, que manda los valores aparte del SQL. Esto quita lo
// que nunca debería venir en un texto escrito por una persona.
import type { NextFunction, Request, Response } from "express";
import { enviarError } from "../errores";

// Más niveles que esto en el JSON no tienen sentido en esta API y solo servirían para gastar CPU
export const PROFUNDIDAD_MAXIMA = 5;

// Llaves que en JavaScript pueden cambiar el prototipo de todos los objetos (prototype pollution)
const LLAVES_PELIGROSAS = new Set(["__proto__", "constructor", "prototype"]);

// Caracteres de control (el byte nulo, el escape de terminal, etc.), salvo el tabulador y los saltos de línea
const CONTROL = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g;
// Caracteres invisibles: de ancho cero y los que invierten la dirección del texto (pueden disfrazar
// un texto para que se lea distinto de lo que dice)
const INVISIBLES = /[​-‏‪-‮⁠-⁤⁦-⁩﻿]/g;
// Etiquetas HTML: un "<" seguido de una letra o de "/letra", hasta el ">". Así "rampa < 2 m" no se toca
const ETIQUETA_HTML = /<\/?[a-zA-Z][^<>]*>/g;
// Un comentario HTML completo, que puede esconder etiquetas
const COMENTARIO_HTML = /<!--[\s\S]*?-->/g;

export type OpcionesLimpieza = {
  // true: conserva los saltos de línea (descripciones). false: los cambia por un espacio (títulos)
  multilinea?: boolean;
};

// Limpia un texto. Es idempotente: limpiarlo dos veces da lo mismo que una.
export function limpiarTexto(texto: string, { multilinea = true }: OpcionesLimpieza = {}): string {
  let limpio = texto.normalize("NFC").replace(/\r\n?/g, "\n").replace(CONTROL, "").replace(INVISIBLES, "");

  // Se repite porque quitar una etiqueta puede juntar los pedazos de otra: "<scr<b>ipt>"
  let anterior: string;
  do {
    anterior = limpio;
    limpio = limpio.replace(COMENTARIO_HTML, "").replace(ETIQUETA_HTML, "");
  } while (limpio !== anterior);

  if (!multilinea) limpio = limpio.replace(/[\n\t]+/g, " ");
  return limpio;
}

// Las contraseñas no se limpian: quitarles caracteres cambiaría la contraseña que eligió la persona
function esContrasena(llave: string): boolean {
  return llave.startsWith("contrasena");
}

export class JsonDemasiadoProfundoError extends Error {
  constructor() {
    super(`El JSON no puede tener más de ${PROFUNDIDAD_MAXIMA} niveles`);
    this.name = "JsonDemasiadoProfundoError";
  }
}

// Recorre el valor y devuelve una copia limpia: limpia los textos, quita las llaves peligrosas y
// rechaza un JSON demasiado anidado. No modifica el original.
export function sanitizarValor(valor: unknown, profundidad = 0): unknown {
  if (typeof valor === "string") return limpiarTexto(valor);
  if (valor === null || typeof valor !== "object") return valor;
  if (profundidad >= PROFUNDIDAD_MAXIMA) throw new JsonDemasiadoProfundoError();

  if (Array.isArray(valor)) return valor.map((elemento) => sanitizarValor(elemento, profundidad + 1));

  // Se arma un objeto nuevo copiando solo las llaves seguras. Copiar "__proto__" con una asignación
  // normal cambiaría el prototipo del objeto nuevo, por eso se descarta antes.
  const limpio: Record<string, unknown> = {};
  for (const [llave, contenido] of Object.entries(valor)) {
    if (LLAVES_PELIGROSAS.has(llave)) continue;
    limpio[llave] = esContrasena(llave) ? contenido : sanitizarValor(contenido, profundidad + 1);
  }
  return limpio;
}

// Middleware global: va justo después de express.json() y antes de las rutas.
// Limpia el cuerpo de la petición. La query y los parámetros los limpia la validación (validar),
// porque en Express 5 `req.query` se vuelve a leer de la URL cada vez y no se puede reemplazar.
export function sanitizar(req: Request, res: Response, next: NextFunction) {
  if (req.body === undefined) return next();
  try {
    req.body = sanitizarValor(req.body);
  } catch (error) {
    if (error instanceof JsonDemasiadoProfundoError) {
      return enviarError(res, 400, "VALIDACION", error.message);
    }
    throw error;
  }
  next();
}
