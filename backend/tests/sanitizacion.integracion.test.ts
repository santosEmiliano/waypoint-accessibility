// Entradas maliciosas contra la BD REAL (#35): comprueba que las consultas son parametrizadas,
// es decir, que un texto con SQL se guarda y se busca como texto y nunca se ejecuta.
// Si la BD no está disponible se salta sola, igual que historial.integracion.test.ts.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/db/prisma";
import { crearReporte, listarReportes, obtenerReporte } from "../src/db/reportes";

async function hayBd(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return (await prisma.estado.count()) === 4 && (await prisma.categoria.count()) >= 1;
  } catch {
    return false;
  }
}

const disponible = await hayBd();
const marca = `prueba-sanitizacion-${Date.now()}`;

const INYECCIONES = [
  "'; DROP TABLE reportes; --",
  "' OR '1'='1",
  "\" OR \"\"=\"",
  "1; DELETE FROM usuarios WHERE 1=1",
  "' UNION SELECT contrasena_usuario FROM usuarios --",
  "\\'; SELECT SLEEP(5); -- ",
];

describe.skipIf(!disponible)("consultas parametrizadas (BD real)", () => {
  let idUsuario: number;
  let idCategoria: number;
  let reportesAntes: number;

  beforeAll(async () => {
    const rol = await prisma.rol.findUniqueOrThrow({ where: { nombreRol: "usuario" } });
    const usuario = await prisma.usuario.create({
      data: { nombreUsuario: "Prueba", correoUsuario: `${marca}@prueba.test`, contrasenaUsuario: "x", idRol: rol.idRol },
    });
    idUsuario = usuario.idUsuario;
    idCategoria = (await prisma.categoria.findFirstOrThrow()).idCategoria;
    reportesAntes = await prisma.reporte.count();
  });

  afterAll(async () => {
    const ids = (await prisma.reporte.findMany({ where: { idUsuario }, select: { idReporte: true } })).map((r) => r.idReporte);
    await prisma.historial.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.reporte.deleteMany({ where: { idReporte: { in: ids } } });
    await prisma.usuario.delete({ where: { idUsuario } });
    await prisma.$disconnect();
  });

  it.each(INYECCIONES)("guarda %j como texto literal y no ejecuta nada", async (inyeccion) => {
    const creado = await crearReporte({
      idUsuario,
      titulo: inyeccion,
      descripcion: inyeccion,
      idCategoria,
      ubicacion: inyeccion,
    });
    const leido = await obtenerReporte(creado.idReporte);
    expect(leido?.tituloReporte).toBe(inyeccion.trim());
    expect(leido?.descripcionReporte).toBe(inyeccion.trim());
  });

  it("las tablas siguen ahí y no se borró nada", async () => {
    // Se cuentan solo los de este usuario: otra prueba puede estar creando reportes al mismo tiempo
    expect(await prisma.reporte.count({ where: { idUsuario } })).toBe(INYECCIONES.length);
    expect(await prisma.reporte.count()).toBeGreaterThanOrEqual(reportesAntes + INYECCIONES.length);
    expect(await prisma.usuario.count({ where: { idUsuario } })).toBe(1);
    expect(await prisma.estado.count()).toBe(4);
  });

  it("buscar con SQL no devuelve todos los reportes: solo los que tienen ese texto", async () => {
    const encontrados = await listarReportes({ texto: "' OR '1'='1" });
    expect(encontrados.length).toBeGreaterThan(0);
    for (const reporte of encontrados) {
      const juntos = `${reporte.tituloReporte} ${reporte.descripcionReporte} ${reporte.ubicacionReporte}`;
      expect(juntos).toContain("' OR '1'='1");
    }
  });

  it("los comodines de LIKE (% y _) se buscan como texto, no como comodín", async () => {
    const conPorcentaje = await crearReporte({ idUsuario, titulo: `${marca} 100% bloqueada`, descripcion: "d", idCategoria, ubicacion: "u" });
    const sinComodines = await crearReporte({ idUsuario, titulo: `${marca} sin comodines`, descripcion: "d", idCategoria, ubicacion: "u" });

    // Sin escapar, "%" devolvería todos los reportes del usuario
    const porcentaje = await listarReportes({ idUsuario, texto: "%" });
    expect(porcentaje.map((r) => r.idReporte)).toEqual([conPorcentaje.idReporte]);

    // Sin escapar, "_" encontraría cualquier carácter. Escapado solo encuentra los que traen un "_"
    // de verdad (como "contrasena_usuario" de una de las inyecciones de arriba)
    const guionBajo = await listarReportes({ idUsuario, texto: "_" });
    expect(guionBajo.map((r) => r.idReporte)).not.toContain(sinComodines.idReporte);
    for (const reporte of guionBajo) {
      expect(`${reporte.tituloReporte} ${reporte.descripcionReporte} ${reporte.ubicacionReporte}`).toContain("_");
    }

    // Una diagonal invertida también se busca tal cual
    const conDiagonal = await crearReporte({ idUsuario, titulo: `${marca} C:\\ruta`, descripcion: "d", idCategoria, ubicacion: "u" });
    const diagonal = await listarReportes({ idUsuario, texto: "C:\\ruta" });
    expect(diagonal.map((r) => r.idReporte)).toEqual([conDiagonal.idReporte]);
  });
});

// Revisión del código fuente: ninguna consulta arma el SQL pegando texto.
// $queryRawUnsafe y $executeRawUnsafe reciben el SQL ya armado y son la puerta a la inyección.
describe("el código no usa SQL armado a mano", () => {
  const src = fileURLToPath(new URL("../src", import.meta.url));

  function archivos(carpeta: string): string[] {
    return readdirSync(carpeta).flatMap((nombre) => {
      const ruta = join(carpeta, nombre);
      if (nombre === "generated") return []; // el cliente que genera Prisma
      return statSync(ruta).isDirectory() ? archivos(ruta) : /\.(ts|js)$/.test(nombre) ? [ruta] : [];
    });
  }

  it("no hay $queryRawUnsafe ni $executeRawUnsafe en src/", () => {
    const usos = archivos(src).filter((ruta) => /\$(queryRaw|executeRaw)Unsafe/.test(readFileSync(ruta, "utf8")));
    expect(usos).toEqual([]);
  });

  it("$queryRaw y $executeRaw solo se usan como plantilla etiquetada (parametrizada)", () => {
    // `prisma.$queryRaw\`...\`` es seguro; `prisma.$queryRaw(texto)` no.
    const usos = archivos(src).filter((ruta) => /\$(queryRaw|executeRaw)\s*\(/.test(readFileSync(ruta, "utf8")));
    expect(usos).toEqual([]);
  });
});
