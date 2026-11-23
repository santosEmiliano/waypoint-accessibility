import express from "express";
import jwt from "jsonwebtoken";
import request from "supertest";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import { crearAutenticar, extraerToken, requerirRol } from "../src/auth/middleware";
import { crearAlmacenMemoria } from "../src/auth/sesiones";
import { cerrarSesion, emitirToken, leerToken } from "../src/auth/token";
import type { UsuarioPublico } from "../src/db/usuarios";

const SECRETO = "secreto-de-pruebas-0123456789";

const usuarioNormal: UsuarioPublico = {
  idUsuario: 1,
  nombreUsuario: "Ana",
  correoUsuario: "ana@correo.com",
  creacionUsuario: new Date("2026-11-20T00:00:00Z"),
  rol: { idRol: 1, nombreRol: "usuario" },
};
const operador: UsuarioPublico = {
  ...usuarioNormal,
  idUsuario: 2,
  nombreUsuario: "Op",
  rol: { idRol: 2, nombreRol: "operador" },
};

let almacen = crearAlmacenMemoria();
let usuarios: Map<number, UsuarioPublico>;

function crearApp() {
  const autenticar = crearAutenticar({
    almacen: async () => almacen,
    buscarUsuario: async (id) => usuarios.get(id) ?? null,
  });
  const app = express();
  app.get("/protegida", autenticar, (req, res) => {
    res.json({ usuario: req.usuario });
  });
  app.get("/operador", autenticar, requerirRol("operador"), (req, res) => {
    res.json({ ok: true });
  });
  app.get("/sin-autenticar", requerirRol("operador"), (req, res) => {
    res.json({ ok: true });
  });
  app.post("/logout", autenticar, async (req, res) => {
    await cerrarSesion(almacen, req.token!);
    res.status(204).end();
  });
  return app;
}

beforeAll(() => {
  process.env.JWT_SECRET = SECRETO;
  process.env.JWT_EXPIRES_IN = "8h";
});

beforeEach(() => {
  almacen = crearAlmacenMemoria();
  usuarios = new Map([
    [usuarioNormal.idUsuario, usuarioNormal],
    [operador.idUsuario, operador],
  ]);
});

describe("autenticar", () => {
  it("rechaza una ruta protegida sin token", async () => {
    const res = await request(crearApp()).get("/protegida");
    expect(res.status).toBe(401);
    expect(res.body.error.codigo).toBe("NO_AUTENTICADO");
  });

  it.each(["Bearer", "Bearer ", "Basic abc", "Bearer a b", "token-suelto", "Bearer basura.que.no.es.jwt"])(
    "rechaza el encabezado %j",
    async (encabezado) => {
      const res = await request(crearApp()).get("/protegida").set("Authorization", encabezado);
      expect(res.status).toBe(401);
      expect(res.body.error.codigo).toBe("NO_AUTENTICADO");
    },
  );

  it("deja pasar un token válido y pone al usuario en la petición", async () => {
    const token = await emitirToken(almacen, 1);
    const res = await request(crearApp()).get("/protegida").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.usuario.correoUsuario).toBe("ana@correo.com");
  });

  it("la contraseña no aparece en la respuesta", async () => {
    const token = await emitirToken(almacen, 1);
    const res = await request(crearApp()).get("/protegida").set("Authorization", `Bearer ${token}`);
    expect(JSON.stringify(res.body).toLowerCase()).not.toContain("contrasena");
  });

  it("rechaza un token vencido", async () => {
    const vencido = jwt.sign({}, SECRETO, { algorithm: "HS256", subject: "1", jwtid: "x", expiresIn: -10 });
    await almacen.guardar("x", 1, 3600);
    const res = await request(crearApp()).get("/protegida").set("Authorization", `Bearer ${vencido}`);
    expect(res.status).toBe(401);
  });

  it("rechaza un token firmado con otro secreto", async () => {
    const falso = jwt.sign({}, "otro-secreto-distinto-123456", { subject: "1", jwtid: "x", expiresIn: "1h" });
    await almacen.guardar("x", 1, 3600);
    const res = await request(crearApp()).get("/protegida").set("Authorization", `Bearer ${falso}`);
    expect(res.status).toBe(401);
  });

  it("rechaza un token con algoritmo 'none'", async () => {
    const cuerpo = Buffer.from(JSON.stringify({ sub: "1", jti: "x" })).toString("base64url");
    const cabecera = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString("base64url");
    await almacen.guardar("x", 1, 3600);
    const res = await request(crearApp()).get("/protegida").set("Authorization", `Bearer ${cabecera}.${cuerpo}.`);
    expect(res.status).toBe(401);
  });

  it("rechaza un token válido cuya sesión no existe", async () => {
    const token = jwt.sign({}, SECRETO, { algorithm: "HS256", subject: "1", jwtid: "sin-sesion", expiresIn: "1h" });
    const res = await request(crearApp()).get("/protegida").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(401);
  });

  it("rechaza el token si el usuario ya no existe", async () => {
    const token = await emitirToken(almacen, 1);
    usuarios.delete(1);
    const res = await request(crearApp()).get("/protegida").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(401);
  });

  it("después del logout el mismo token responde 401", async () => {
    const app = crearApp();
    const token = await emitirToken(almacen, 1);
    expect((await request(app).get("/protegida").set("Authorization", `Bearer ${token}`)).status).toBe(200);
    expect((await request(app).post("/logout").set("Authorization", `Bearer ${token}`)).status).toBe(204);
    expect((await request(app).get("/protegida").set("Authorization", `Bearer ${token}`)).status).toBe(401);
  });

  it("dos sesiones del mismo usuario son independientes", async () => {
    const app = crearApp();
    const a = await emitirToken(almacen, 1);
    const b = await emitirToken(almacen, 1);
    await request(app).post("/logout").set("Authorization", `Bearer ${a}`);
    expect((await request(app).get("/protegida").set("Authorization", `Bearer ${b}`)).status).toBe(200);
  });
});

describe("requerirRol", () => {
  it("un usuario no puede usar rutas de operador", async () => {
    const token = await emitirToken(almacen, 1);
    const res = await request(crearApp()).get("/operador").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(403);
    expect(res.body.error.codigo).toBe("SIN_PERMISO");
  });

  it("un operador sí puede", async () => {
    const token = await emitirToken(almacen, 2);
    const res = await request(crearApp()).get("/operador").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(200);
  });

  it("sin pasar por autenticar responde 401 y no deja pasar", async () => {
    const res = await request(crearApp()).get("/sin-autenticar");
    expect(res.status).toBe(401);
  });

  it("el rol sale de la BD, no del token: si lo bajan de rango pierde el acceso", async () => {
    const token = await emitirToken(almacen, 2);
    usuarios.set(2, { ...operador, rol: { idRol: 1, nombreRol: "usuario" } });
    const res = await request(crearApp()).get("/operador").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(403);
  });
});

describe("token", () => {
  it("el token vence según JWT_EXPIRES_IN y la sesión también", async () => {
    process.env.JWT_EXPIRES_IN = "2h";
    const token = await emitirToken(almacen, 1);
    const { exp, iat } = jwt.decode(token) as { exp: number; iat: number };
    expect(exp - iat).toBe(7200);
    process.env.JWT_EXPIRES_IN = "8h";
  });

  it("leerToken devuelve null con basura y los datos con un token bueno", async () => {
    expect(leerToken("basura")).toBeNull();
    const token = await emitirToken(almacen, 7);
    expect(leerToken(token)?.idUsuario).toBe(7);
  });

  it("falla con un JWT_SECRET demasiado corto en vez de firmar con un secreto débil", async () => {
    process.env.JWT_SECRET = "corto";
    await expect(emitirToken(almacen, 1)).rejects.toThrow(/JWT_SECRET/);
    process.env.JWT_SECRET = SECRETO;
  });
});

describe("extraerToken", () => {
  it("acepta 'bearer' en minúsculas", () => {
    expect(extraerToken({ headers: { authorization: "bearer abc" } } as never)).toBe("abc");
  });
});
