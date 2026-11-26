import { describe, it, expect } from 'vitest';
import request from 'supertest';

// CORS_ORIGIN se lee al importar la app, por eso va antes del import.
// El espacio después de la coma es a propósito: comprueba que se recorta.
process.env.CORS_ORIGIN = 'http://localhost:8080, http://localhost:3001';
const { default: app } = await import('../src/app');

describe('GET /health', () => {
  it('responde que el servidor está activo', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ estado: 'ok' });
  });
});

describe('Errores', () => {
  it('responde 404 RUTA_NO_ENCONTRADA si la ruta no existe', async () => {
    const res = await request(app).get('/no-existe');

    expect(res.status).toBe(404);
    expect(res.body.error.codigo).toBe('RUTA_NO_ENCONTRADA');
  });

  it('responde 400 VALIDACION si el JSON está mal formado', async () => {
    const res = await request(app)
      .post('/health')
      .set('Content-Type', 'application/json')
      .send('{"correo_usuario": "ana@');

    expect(res.status).toBe(400);
    expect(res.body.error.codigo).toBe('VALIDACION');
  });

  it('responde 400 VALIDACION si el JSON pasa de 20 KB', async () => {
    const res = await request(app)
      .post('/health')
      .send({ texto: 'a'.repeat(30000) });

    expect(res.status).toBe(400);
    expect(res.body.error.codigo).toBe('VALIDACION');
  });
});

describe('CORS', () => {
  it('permite el origen de la versión web', async () => {
    const res = await request(app).get('/health').set('Origin', 'http://localhost:8080');

    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:8080');
  });

  it('permite varios orígenes aunque lleven espacio después de la coma', async () => {
    const res = await request(app).get('/health').set('Origin', 'http://localhost:3001');

    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:3001');
  });

  it('no permite un origen ajeno', async () => {
    const res = await request(app).get('/health').set('Origin', 'https://otro-sitio.com');

    expect(res.headers['access-control-allow-origin']).toBeUndefined();
  });
});
