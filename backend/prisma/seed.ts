// Semilla de Waypoint: roles, categorías, estados y un operador.
// Es idempotente: se puede correr las veces que sea sin duplicar nada (upsert por nombre o correo).
// Se corre con `npm run db:seed` desde backend/.
import bcrypt from "bcryptjs";
import { prisma } from "../src/db/prisma";

const ROLES = ["usuario", "operador"];

const CATEGORIAS = [
  "Rampas y accesos",
  "Elevadores",
  "Rutas y banquetas",
  "Señalización",
  "Baños",
  "Mobiliario",
  "Iluminación",
  "Otro",
];

// ordenEstado decide qué transición es válida (nuevo = actual + 1)
const ESTADOS = [
  { nombreEstado: "Reportado", ordenEstado: 1 },
  { nombreEstado: "En análisis", ordenEstado: 2 },
  { nombreEstado: "En atención", ordenEstado: 3 },
  { nombreEstado: "Resuelto", ordenEstado: 4 },
];

const RONDAS_BCRYPT = 12;

function leerOperador() {
  const correo = process.env.SEED_OPERADOR_CORREO?.trim().toLowerCase();
  const contrasena = process.env.SEED_OPERADOR_CONTRASENA;
  if (!correo || !contrasena) {
    throw new Error("Faltan SEED_OPERADOR_CORREO o SEED_OPERADOR_CONTRASENA en el .env");
  }
  if (contrasena.length < 8) {
    throw new Error("SEED_OPERADOR_CONTRASENA debe tener al menos 8 caracteres");
  }
  return { correo, contrasena };
}

async function main() {
  const operador = leerOperador();
  // El hash se calcula antes de abrir la transacción porque bcrypt es lento a propósito
  const hash = await bcrypt.hash(operador.contrasena, RONDAS_BCRYPT);

  await prisma.$transaction(async (tx) => {
    for (const nombreRol of ROLES) {
      await tx.rol.upsert({ where: { nombreRol }, update: {}, create: { nombreRol } });
    }

    for (const nombreCategoria of CATEGORIAS) {
      await tx.categoria.upsert({
        where: { nombreCategoria },
        update: {},
        create: { nombreCategoria },
      });
    }

    for (const estado of ESTADOS) {
      await tx.estado.upsert({
        where: { nombreEstado: estado.nombreEstado },
        update: { ordenEstado: estado.ordenEstado },
        create: estado,
      });
    }

    const rolOperador = await tx.rol.findUniqueOrThrow({ where: { nombreRol: "operador" } });

    // Si el operador ya existe no se toca (ni su contraseña ni su rol)
    await tx.usuario.upsert({
      where: { correoUsuario: operador.correo },
      update: {},
      create: {
        nombreUsuario: "Operador de prueba",
        correoUsuario: operador.correo,
        contrasenaUsuario: hash,
        idRol: rolOperador.idRol,
      },
    });
  });

  const [roles, categorias, estados, operadores] = await Promise.all([
    prisma.rol.count(),
    prisma.categoria.count(),
    prisma.estado.count(),
    prisma.usuario.count({ where: { rol: { nombreRol: "operador" } } }),
  ]);
  console.log(`Semilla lista: ${roles} roles, ${categorias} categorías, ${estados} estados, ${operadores} operador(es)`);
}

main()
  .catch((error) => {
    console.error("Error en la semilla:", error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
