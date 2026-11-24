import express, { type NextFunction, type Request, type Response } from 'express';
import cors from 'cors';

const app = express();

// body-parser agrega `type` a sus errores, por ejemplo entity.parse.failed o entity.too.large
type ErrorDeExpress = Error & { type?: string };

// Sin CORS_ORIGIN no se permite ningún origen web; varios se separan con comas.
// trim quita el espacio después de cada coma; con él, el origen ya no coincide y el navegador bloquea sin avisar.
app.use(
  cors({
    origin: process.env.CORS_ORIGIN
      ? process.env.CORS_ORIGIN.split(',').map((origen) => origen.trim())
      : false,
  }),
);
app.use(express.json({ limit: '20kb' }));

app.get('/health', (req, res) => {
  res.json({ estado: 'ok' });
});

app.use((req, res) => {
  res.status(404).json({ error: { codigo: 'RUTA_NO_ENCONTRADA', mensaje: 'La ruta no existe' } });
});

// Express lo reconoce como manejador de errores por tener cuatro parámetros
app.use((error: ErrorDeExpress, req: Request, res: Response, next: NextFunction) => {
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { codigo: 'VALIDACION', mensaje: 'El cuerpo no es un JSON válido' } });
  }
  if (error.type === 'entity.too.large') {
    return res.status(400).json({ error: { codigo: 'VALIDACION', mensaje: 'El cuerpo de la petición es demasiado grande' } });
  }
  console.error(error);
  res.status(500).json({ error: { codigo: 'ERROR_INTERNO', mensaje: 'Ocurrió un error en el servidor' } });
});

export default app;
