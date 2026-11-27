// Los middlewares juntos, en el orden en que los van a usar las rutas (#50):
//   express.json → sanitizar → autenticar → requerirRol → validar → controlador
// Cada middleware ya tiene sus pruebas por separado; aquí se prueba que juntos respondan lo correcto
// y qué pasa cuando Redis o la BD no responden. Usa sesiones en memoria y usuarios falsos.
import express, { type NextFunction, type Request, type Response } from "express";
import request from "supertest";
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { crearAutenticar, requerirRol } from "../src/auth/middleware";
import { crearAlmacenMemoria, type AlmacenSesiones } from "../src/auth/sesiones";
import { emitirToken } from "../src/auth/token";
import type { UsuarioPublico } from "../src/db/usuarios";
import { esquemas } from "../src/middlewares/esquemas";
import { sanitizar } from "../src/middlewares/sanitizacion";
import { validar } from "../src/middlewares/validacion";

const usuarioNormal: UsuarioPublico = {
  idUsuario: 1,
  nombreUsuario: "Ana",
  correoUsuario: "ana@correo.com",
  creacionUsuario: new Date("2026-11-20T00:00:00Z"),
  rol: { idRol: 1, nombreRol: "usuario" },
};
const operador: UsuarioPublico = { ...usuarioNormal, idUsuario: 2, nombreUsuario: "Op", rol: { idRol: 2, nombreRol: "operador" } };

let almacen: AlmacenSesiones;
let obtenerAlmacen: () => Promise<AlmacenSesiones>;
let buscarUsuario: (id: number) => Promise<UsuarioPublico | null>;

function crearApp() {
  const autenticar = crearAutenticar({ almacen: () => obtenerAlmacen(), buscarUsuario: (id) => buscarUsuario(id) });
  const app = express();
  app.use(express.json({ limit: "20kb" }));
  app.use(sanitizar);

  // Lo que recibe el controlador
  const eco = (req: Request, res: Response) => res.json({ body: req.body, params: req.validado?.params });
  app.post("/reportes", autenticar, validar(esquemas.crearReporte), eco);
  app.post("/reportes/:id/acciones", autenticar, requerirRol("operador"), validar(esquemas.accionCorrectiva), eco);

  // El mismo manejador de errores que backend/src/app.js
  app.use((error: Error, req: Request, res: Response, _next: NextFunction) => {
    console.error(error);
    res.status(500).json({ error: { codigo: "ERROR_INTERNO", mensaje: "Ocurrió un error en el servidor" } });
  });
  return app;
}

const conToken = async (usuario: UsuarioPublico) => `Bearer ${await emitirToken(almacen, usuario.idUsuario)}`;

const reporteValido = {
  titulo_reporte: "Rampa rota",
  descripcion_reporte: "La rampa del edificio 3 tiene un hoyo",
  id_categoria: 1,
  ubicacion_reporte: "Edificio 3",
  latitud_reporte: null,
  longitud_reporte: null,
};

beforeAll(() => {
  process.env.JWT_SECRET = "secreto-de-pruebas-0123456789";
  process.env.JWT_EXPIRES_IN = "8h";
});

beforeEach(() => {
  almacen = crearAlmacenMemoria();
  obtenerAlmacen = async () => almacen;
  const usuarios = new Map([
    [usuarioNormal.idUsuario, usuarioNormal],
    [operador.idUsuario, operador],
  ]);
  buscarUsuario = async (id) => usuarios.get(id) ?? null;
  // El manejador de errores escribe en la consola; aquí solo ensuciaría la salida
  vi.spyOn(console, "error").mockImplementation(() => {});
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("orden de los middlewares", () => {
  it("sin token responde 401 aunque el cuerpo esté mal: no revela qué se valida", async () => {
    const res = await request(crearApp()).post("/reportes/1/acciones").send({ descripcion_historial: "" });
    expect(res.status).toBe(401);
    expect(res.body.error.codigo).toBe("NO_AUTENTICADO");
  });

  it("un usuario en una ruta de operador responde 403 aunque el cuerpo esté mal", async () => {
    const res = await request(crearApp())
      .post("/reportes/1/acciones")
      .set("Authorization", await conToken(usuarioNormal))
      .send({});
    expect(res.status).toBe(403);
    expect(res.body.error.codigo).toBe("SIN_PERMISO");
  });

  it("con sesión y permiso, un cuerpo mal formado responde 400 con el campo", async () => {
    const res = await request(crearApp())
      .post("/reportes/abc/acciones")
      .set("Authorization", await conToken(operador))
      .send({ descripcion_historial: "   " });
    expect(res.status).toBe(400);
    expect(res.body.error.codigo).toBe("VALIDACION");
    expect(Object.keys(res.body.error.campos).sort()).toEqual(["descripcion_historial", "id"]);
  });

  it("un JSON demasiado anidado se rechaza antes de autenticar (lo corta sanitizar, que va antes que las rutas)", async () => {
    const res = await request(crearApp()).post("/reportes").send({ a: { b: { c: { d: { e: { f: 1 } } } } } });
    expect(res.status).toBe(400);
    expect(res.body.error.codigo).toBe("VALIDACION");
  });
});

describe("lo que llega al controlador", () => {
  it("el texto llega limpio, el id como número y sin los campos que no están en el esquema", async () => {
    const res = await request(crearApp())
      .post("/reportes/7/acciones")
      .set("Authorization", await conToken(operador))
      .send({ descripcion_historial: "  <b>Se colocó</b> una rampa​ nueva  ", id_usuario: 99 });
    expect(res.status).toBe(200);
    expect(res.body.body).toEqual({ descripcion_historial: "Se colocó una rampa nueva" });
    expect(res.body.params).toEqual({ id: 7 });
  });

  it("un usuario no puede elegir el estado ni el dueño de su reporte: esos campos se descartan", async () => {
    const res = await request(crearApp())
      .post("/reportes")
      .set("Authorization", await conToken(usuarioNormal))
      .send({ ...reporteValido, titulo_reporte: "<b>Rampa</b> rota", id_estado: 4, id_usuario: 2 });
    expect(res.status).toBe(200);
    expect(res.body.body.titulo_reporte).toBe("Rampa rota");
    expect(res.body.body).not.toHaveProperty("id_estado");
    expect(res.body.body).not.toHaveProperty("id_usuario");
  });
});

describe("si Redis o la BD no responden", () => {
  it("con Redis caído responde 500 ERROR_INTERNO, no 401: no cierra la sesión de nadie", async () => {
    const token = await conToken(usuarioNormal);
    obtenerAlmacen = async () => {
      throw new Error("connect ECONNREFUSED 127.0.0.1:6379");
    };
    const res = await request(crearApp()).post("/reportes").set("Authorization", token).send(reporteValido);
    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: { codigo: "ERROR_INTERNO", mensaje: "Ocurrió un error en el servidor" } });
  });

  it("con la BD caída responde 500 ERROR_INTERNO y el detalle del error no sale en la respuesta", async () => {
    const token = await conToken(usuarioNormal);
    buscarUsuario = async () => {
      throw new Error("pool failed to retrieve a connection from pool (connect ECONNREFUSED 127.0.0.1:3306)");
    };
    const res = await request(crearApp()).post("/reportes").set("Authorization", token).send(reporteValido);
    expect(res.status).toBe(500);
    expect(res.body.error.codigo).toBe("ERROR_INTERNO");
    expect(JSON.stringify(res.body)).not.toContain("ECONNREFUSED");
    // El detalle sí queda en la consola del servidor, para poder diagnosticarlo
    expect(console.error).toHaveBeenCalled();
  });

  it("cuando la BD vuelve, la misma sesión sigue funcionando", async () => {
    const token = await conToken(usuarioNormal);
    const real = buscarUsuario;
    buscarUsuario = async () => {
      throw new Error("BD caída");
    };
    expect((await request(crearApp()).post("/reportes").set("Authorization", token).send(reporteValido)).status).toBe(500);

    buscarUsuario = real;
    expect((await request(crearApp()).post("/reportes").set("Authorization", token).send(reporteValido)).status).toBe(200);
  });
});
