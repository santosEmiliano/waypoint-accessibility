// Sesiones activas. Un token solo sirve mientras su sesión exista aquí: cerrar sesión la borra,
// y así el token deja de funcionar aunque no haya vencido.
import type { RedisClientType } from "redis";

export interface AlmacenSesiones {
  guardar(idSesion: string, idUsuario: number, segundos: number): Promise<void>;
  existe(idSesion: string): Promise<boolean>;
  borrar(idSesion: string): Promise<void>;
}

const prefijo = (idSesion: string) => `sesion:${idSesion}`;

export function crearAlmacenRedis(cliente: RedisClientType): AlmacenSesiones {
  return {
    async guardar(idSesion, idUsuario, segundos) {
      // EX hace que Redis la borre sola cuando vence el token
      await cliente.set(prefijo(idSesion), String(idUsuario), { EX: Math.max(1, Math.ceil(segundos)) });
    },
    async existe(idSesion) {
      return (await cliente.exists(prefijo(idSesion))) === 1;
    },
    async borrar(idSesion) {
      await cliente.del(prefijo(idSesion));
    },
  };
}

// Para pruebas: no necesita Redis
export function crearAlmacenMemoria(ahora: () => number = Date.now): AlmacenSesiones & { tamano(): number } {
  const sesiones = new Map<string, number>();
  return {
    async guardar(idSesion, _idUsuario, segundos) {
      sesiones.set(idSesion, ahora() + segundos * 1000);
    },
    async existe(idSesion) {
      const vence = sesiones.get(idSesion);
      if (vence === undefined) return false;
      if (vence <= ahora()) {
        sesiones.delete(idSesion);
        return false;
      }
      return true;
    },
    async borrar(idSesion) {
      sesiones.delete(idSesion);
    },
    tamano: () => sesiones.size,
  };
}
