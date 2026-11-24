// Funciones de acceso a datos de categorías y estados. Están documentadas en docs/db-functions.md.
// Son catálogos de solo lectura: sus filas vienen de la semilla y la API nunca las modifica.
import { prisma } from "./prisma";

export type Categoria = { idCategoria: number; nombreCategoria: string };
export type Estado = { idEstado: number; nombreEstado: string; ordenEstado: number };

// Todas las categorías, en orden alfabético
export async function listarCategorias(): Promise<Categoria[]> {
  return prisma.categoria.findMany({
    select: { idCategoria: true, nombreCategoria: true },
    orderBy: { nombreCategoria: "asc" },
  });
}

// Los 4 estados, del primero al último según su orden (nunca según el id)
export async function listarEstados(): Promise<Estado[]> {
  return prisma.estado.findMany({
    select: { idEstado: true, nombreEstado: true, ordenEstado: true },
    orderBy: { ordenEstado: "asc" },
  });
}
