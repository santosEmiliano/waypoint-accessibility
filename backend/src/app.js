import express from 'express';
import cors from 'cors';

const app = express();

// Sin CORS_ORIGIN no se permite ningún origen web; varios se separan con comas
app.use(cors({ origin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : false }));
app.use(express.json({ limit: '20kb' }));

app.get('/health', (req, res) => {
  res.json({ estado: 'ok' });
});

export default app;
