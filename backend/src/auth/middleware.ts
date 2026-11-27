// Middleware de autenticación y de roles. Los permisos se comprueban aquí, en el backend:
// ocultar botones en la app no protege nada.
import type { NextFunction, Request, RequestHandler, Response } from "express";
import { enviarError } from "../errores";
import { buscarUsuarioPorId, type UsuarioPublico } from "../db/usuarios";
import { obtenerRedis } from "../redis";
import { crearAlmacenRedis, type AlmacenSesiones } from "./sesiones";
import { leerToken } from "./token";

declare global {
  namespace Express {
    interface Request {
      // Lo llena `autenticar`. Es un UsuarioPublico: no trae el hash de la contraseña.
      usuario?: UsuarioPublico;
      // El token con el que entró, para poder cerrarlo en el logout
      token?: string;
    }
  }
}

const NO_AUTENTICADO = "Inicia sesión para continuar";

// Saca el token del encabezado "Authorization: Bearer <token>"
export function extraerToken(req: Request): string | null {
  const encabezado = req.headers.authorization;
  if (!encabezado) return null;
  const [esquema, token, ...resto] = encabezado.split(" ");
  if (esquema?.toLowerCase() !== "bearer" || !token || resto.length > 0) return null;
  return token;
}

type Dependencias = {
  almacen: () => Promise<AlmacenSesiones>;
  buscarUsuario: (idUsuario: number) => Promise<UsuarioPublico | null>;
};

// Se separa de `autenticar` para poder probarlo sin Redis ni BD
export function crearAutenticar(dependencias: Dependencias): RequestHandler {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const token = extraerToken(req);
      const datos = token ? leerToken(token) : null;
      if (!token || !datos) return enviarError(res, 401, "NO_AUTENTICADO", NO_AUTENTICADO);

      // El token puede ser válido pero su sesión ya estar cerrada (logout)
      const almacen = await dependencias.almacen();
      if (!(await almacen.existe(datos.idSesion))) {
        return enviarError(res, 401, "NO_AUTENTICADO", NO_AUTENTICADO);
      }

      // Se lee de la BD para tener el rol actual y rechazar cuentas que ya no existen
      const usuario = await dependencias.buscarUsuario(datos.idUsuario);
      if (!usuario) return enviarError(res, 401, "NO_AUTENTICADO", NO_AUTENTICADO);

      req.usuario = usuario;
      req.token = token;
      next();
    } catch (error) {
      next(error);
    }
  };
}

// El que usan las rutas: Redis para las sesiones y la BD para el usuario
export const autenticar = crearAutenticar({
  almacen: async () => crearAlmacenRedis(await obtenerRedis()),
  buscarUsuario: buscarUsuarioPorId,
});

// Se pone después de `autenticar`. Ejemplo: router.get("/admin", autenticar, requerirRol("operador"), ...)
export function requerirRol(...rolesPermitidos: string[]): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.usuario) return enviarError(res, 401, "NO_AUTENTICADO", NO_AUTENTICADO);
    if (!rolesPermitidos.includes(req.usuario.rol.nombreRol)) {
      return enviarError(res, 403, "SIN_PERMISO", "No tienes permiso para usar esta ruta");
    }
    next();
  };
}

export const soloOperador = requerirRol("operador");
