// Formato de error de toda la API: { error: { codigo, mensaje } } (ver docs/api.md, sección de errores)
import type { Response } from "express";

export function enviarError(res: Response, estado: number, codigo: string, mensaje: string) {
  return res.status(estado).json({ error: { codigo, mensaje } });
}
