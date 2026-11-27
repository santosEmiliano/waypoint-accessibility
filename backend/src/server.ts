import app from './app';
import { prisma } from './db/prisma';

const puerto = Number(process.env.PORT) || 3000;

// Solo se describe la parte del error de Prisma que se usa abajo
type ErrorDeConexion = { meta?: { driverAdapterError?: { cause?: { cause?: string } } } };

// Se comprueba la BD antes de abrir el puerto, para que el servidor no arranque sin ella
console.log('Conectando a la BD...');
try {
  await prisma.$queryRaw`SELECT 1`;
  console.log('Conectado a la BD');
} catch (error) {
  // Prisma guarda la causa real (por ejemplo, ECONNREFUSED) dentro de meta
  const causa =
    (error as ErrorDeConexion).meta?.driverAdapterError?.cause?.cause ??
    (error instanceof Error ? error.message : String(error));
  console.error(`No se pudo conectar a la BD: ${causa}`);
  console.error('Revisa que la BD esté levantada (docker compose up -d) y que DATABASE_URL del .env tenga el usuario y la contraseña correctos');
  process.exit(1);
}

// Express 5 pasa el error al callback si el puerto no está disponible
app.listen(puerto, (error) => {
  if (error) {
    console.error(`No se pudo iniciar el servidor en el puerto ${puerto}: ${error.message}`);
    process.exit(1);
  }
  console.log(`Servidor escuchando en http://localhost:${puerto}`);
});
