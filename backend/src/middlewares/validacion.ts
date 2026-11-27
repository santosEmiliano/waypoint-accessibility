// Validación del cuerpo, los parámetros y la query de cada ruta (#34).
// Está documentada en docs/validacion-sanitizacion.md; los esquemas de cada ruta están en esquemas.ts.
//
// Un esquema dice qué campos acepta la ruta y la regla de cada uno. El middleware revisa todos los
// campos, junta los errores en `campos` y responde 400 VALIDACION con el formato de docs/api.md.
// Si todo está bien, deja los datos ya limpios y convertidos en `req.validado` y sigue.
import type { NextFunction, Request, Response } from "express";
import { validarContrasena } from "../auth/contrasenas";
import { limpiarTexto } from "./sanitizacion";

// Una regla recibe el valor tal como llegó y devuelve el valor limpio o el mensaje de error.
// `valor: undefined` en un resultado correcto significa "no se mandó" y el campo no se incluye.
export type Resultado = { ok: true; valor: unknown } | { ok: false; error: string };
export type Regla = (valor: unknown) => Resultado;
export type Campos = Record<string, Regla>;

// Revisa reglas entre varios campos (por ejemplo, latitud y longitud juntas).
// Recibe los datos ya validados y devuelve los errores por campo, o null.
export type ReglaCruzada = (datos: Record<string, unknown>) => Record<string, string> | null;

export type Seccion = { campos: Campos; cruzadas?: ReglaCruzada[] };
export type Esquema = { body?: Seccion; params?: Seccion; query?: Seccion };

export type DatosValidados = {
  body: Record<string, unknown>;
  params: Record<string, unknown>;
  query: Record<string, unknown>;
};

declare global {
  namespace Express {
    interface Request {
      // Lo deja `validar`: solo los campos del esquema, ya limpios y convertidos
      validado?: DatosValidados;
    }
  }
}

export const MENSAJES = {
  obligatorio: "Es obligatorio",
  formato: "Formato inválido",
} as const;

const bien = (valor: unknown): Resultado => ({ ok: true, valor });
const mal = (error: string): Resultado => ({ ok: false, error });
const vacio = (valor: unknown) => valor === undefined || valor === null || valor === "";

// Cuenta caracteres como los cuenta MySQL (utf8mb4): un emoji es 1, no 2 como en `.length`
function largo(texto: string): number {
  return Array.from(texto).length;
}

type OpcionesTexto = { min?: number; max: number; multilinea?: boolean };

// Texto obligatorio: lo limpia, le quita los espacios de los extremos y revisa el largo
export function texto({ min = 1, max, multilinea = false }: OpcionesTexto): Regla {
  return (valor) => {
    if (valor === undefined || valor === null) return mal(MENSAJES.obligatorio);
    if (typeof valor !== "string") return mal(MENSAJES.formato);
    const limpio = limpiarTexto(valor, { multilinea }).trim();
    if (limpio === "") return mal(MENSAJES.obligatorio);
    const n = largo(limpio);
    if (n < min || n > max) return mal(min === 1 ? `Máximo ${max} caracteres` : `De ${min} a ${max} caracteres`);
    return bien(limpio);
  };
}

// Entero positivo. Acepta 7 o "7", porque los parámetros y la query siempre llegan como texto.
// `max` es el máximo de la columna: si se pasa, Prisma fallaría con un 500 en vez de un 400.
export function entero({ min = 1, max }: { min?: number; max: number }): Regla {
  return (valor) => {
    if (vacio(valor)) return mal(MENSAJES.obligatorio);
    let numero: number;
    if (typeof valor === "number") numero = valor;
    else if (typeof valor === "string" && /^\d{1,10}$/.test(valor.trim())) numero = Number(valor.trim());
    else return mal(MENSAJES.formato);
    if (!Number.isInteger(numero) || numero < min || numero > max) return mal(MENSAJES.formato);
    return bien(numero);
  };
}

// Número con decimales dentro de un rango, con un máximo de decimales (las coordenadas son DECIMAL(9,6))
export function decimal({ min, max, decimales }: { min: number; max: number; decimales: number }): Regla {
  const escala = 10 ** decimales;
  return (valor) => {
    if (vacio(valor)) return mal(MENSAJES.obligatorio);
    if (typeof valor !== "number" || !Number.isFinite(valor)) return mal(MENSAJES.formato);
    if (valor < min || valor > max) return mal(`Debe estar entre ${min} y ${max}`);
    // Se compara con tolerancia: 21.91356 * 1e6 da 21913560.000000004 por cómo se guardan los decimales
    if (Math.abs(valor * escala - Math.round(valor * escala)) > 1e-6) return mal(`Máximo ${decimales} decimales`);
    return bien(valor);
  };
}

// true o false. En la query llega como texto: "true" o "false"
export function booleano(): Regla {
  return (valor) => {
    if (typeof valor === "boolean") return bien(valor);
    if (valor === "true") return bien(true);
    if (valor === "false") return bien(false);
    return vacio(valor) ? mal(MENSAJES.obligatorio) : mal(MENSAJES.formato);
  };
}

// Uno de los valores de la lista, escrito igual (por ejemplo, el orden del listado)
export function unoDe(valores: readonly string[]): Regla {
  return (valor) => {
    if (vacio(valor)) return mal(MENSAJES.obligatorio);
    if (typeof valor !== "string" || !valores.includes(valor.trim())) {
      return mal(`Debe ser uno de: ${valores.join(", ")}`);
    }
    return bien(valor.trim());
  };
}

const PATRON_CORREO =/^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Correo con formato válido. Se guarda en minúsculas (lo hace también normalizarCorreo en la BD)
export function correo({ max }: { max: number }): Regla {
  return (valor) => {
    if (vacio(valor)) return mal(MENSAJES.obligatorio);
    if (typeof valor !== "string") return mal(MENSAJES.formato);
    const limpio = valor.trim().toLowerCase();
    if (largo(limpio) > max || !PATRON_CORREO.test(limpio)) return mal(MENSAJES.formato);
    return bien(limpio);
  };
}

// Contraseña nueva: mínimo 8 caracteres y máximo 72 bytes (las reglas de auth/contrasenas.ts).
// No se limpia ni se recorta: los espacios y símbolos son parte de la contraseña.
export function contrasenaNueva(): Regla {
  return (valor) => {
    if (vacio(valor)) return mal(MENSAJES.obligatorio);
    if (typeof valor !== "string") return mal(MENSAJES.formato);
    const error = validarContrasena(valor);
    return error ? mal(error) : bien(valor);
  };
}

// Contraseña que se va a comparar (login, contraseña actual): solo se pide que venga.
// No se le aplica el mínimo, para que una regla nueva no deje fuera a una cuenta vieja.
export function contrasenaGuardada(): Regla {
  return (valor) => {
    if (vacio(valor)) return mal(MENSAJES.obligatorio);
    if (typeof valor !== "string") return mal(MENSAJES.formato);
    return bien(valor);
  };
}

// Si la regla dice "Es obligatorio" (no vino, viene vacío, solo espacios o quedó vacío al limpiarlo),
// en un campo opcional eso significa "no se mandó" y se usa `siFalta`
function siNoVino(regla: Regla, siFalta: unknown): Regla {
  return (valor) => {
    const resultado = regla(valor);
    return !resultado.ok && resultado.error === MENSAJES.obligatorio ? bien(siFalta) : resultado;
  };
}

// Vuelve opcional una regla: si no se manda, el campo se omite
export function opcional(regla: Regla): Regla {
  return siNoVino(regla, undefined);
}

// Como opcional, pero si no se manda el valor queda en null (para columnas que aceptan NULL)
export function nulable(regla: Regla): Regla {
  return siNoVino(regla, null);
}

function esObjeto(valor: unknown): valor is Record<string, unknown> {
  return typeof valor === "object" && valor !== null && !Array.isArray(valor);
}

// Valida una sección (body, params o query). Devuelve los datos limpios y los errores por campo.
export function validarSeccion(seccion: Seccion, entrada: unknown) {
  const origen = esObjeto(entrada) ? entrada : {};
  const datos: Record<string, unknown> = {};
  const errores: Record<string, string> = {};

  // Solo se recorren los campos del esquema: lo que no está en él se ignora (por ejemplo, un `rol`
  // que alguien agregue al registro para hacerse operador)
  for (const [nombre, regla] of Object.entries(seccion.campos)) {
    const resultado = regla(origen[nombre]);
    if (!resultado.ok) errores[nombre] = resultado.error;
    else if (resultado.valor !== undefined) datos[nombre] = resultado.valor;
  }

  // Las reglas cruzadas solo corren si cada campo por separado está bien
  if (Object.keys(errores).length === 0) {
    for (const cruzada of seccion.cruzadas ?? []) Object.assign(errores, cruzada(datos));
  }
  return { datos, errores };
}

// El middleware. Uso: router.post("/reportes", autenticar, validar(esquemas.crearReporte), controlador)
export function validar(esquema: Esquema) {
  return (req: Request, res: Response, next: NextFunction) => {
    // Un cuerpo que no es un objeto (un arreglo, un texto) no puede traer campos
    if (esquema.body && req.body !== undefined && !esObjeto(req.body)) {
      return res.status(400).json({
        error: { codigo: "VALIDACION", mensaje: "El cuerpo debe ser un objeto JSON", campos: {} },
      });
    }

    const validado: DatosValidados = { body: {}, params: {}, query: {} };
    const campos: Record<string, string> = {};
    for (const parte of ["params", "query", "body"] as const) {
      const seccion = esquema[parte];
      if (!seccion) continue;
      const { datos, errores } = validarSeccion(seccion, req[parte]);
      validado[parte] = datos;
      Object.assign(campos, errores);
    }

    if (Object.keys(campos).length > 0) {
      return res.status(400).json({ error: { codigo: "VALIDACION", mensaje: "Hay campos inválidos", campos } });
    }

    req.validado = validado;
    // El cuerpo se reemplaza por el validado, para que el controlador no use por error un campo que no se revisó
    if (esquema.body) req.body = validado.body;
    next();
  };
}
