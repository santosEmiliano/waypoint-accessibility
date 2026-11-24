import express from "express";
import request from "supertest";
import { afterEach, describe, expect, it } from "vitest";
import { limpiarTexto, PROFUNDIDAD_MAXIMA, sanitizar, sanitizarValor } from "../src/middlewares/sanitizacion";

// Misma cadena que app.js: primero se lee el JSON y luego se limpia
function crearApp() {
  const app = express();
  app.use(express.json());
  app.use(sanitizar);
  app.post("/eco", (req, res) => {
    res.json({ body: req.body ?? null });
  });
  return app;
}

describe("limpiarTexto: entradas maliciosas básicas", () => {
  it.each([
    ["<script>alert(1)</script>", "alert(1)"],
    ['<img src=x onerror="alert(1)">', ""],
    ["<svg/onload=alert(1)>", ""],
    ['<a href="javascript:alert(1)">clic</a>', "clic"],
    ["<iframe src=//malo.com></iframe>Rampa", "Rampa"],
    ["<!-- <script>alert(1)</script> -->Rampa", "Rampa"],
    ["<scr<b>ipt>alert(1)</scr</b>ipt>", "alert(1)"],
    ["Rampa <b>rota</b>", "Rampa rota"],
  ])("quita las etiquetas HTML de %j", (entrada, esperado) => {
    expect(limpiarTexto(entrada)).toBe(esperado);
  });

  it("no toca un '<' o '>' que no forma una etiqueta", () => {
    expect(limpiarTexto("La rampa mide < 2 m y el escalón > 15 cm")).toBe("La rampa mide < 2 m y el escalón > 15 cm");
    expect(limpiarTexto("3<5 y 7>2")).toBe("3<5 y 7>2");
  });

  it("deja la inyección SQL como texto literal: la protección es la consulta parametrizada", () => {
    const sql = "'; DROP TABLE reportes; -- \" OR 1=1";
    expect(limpiarTexto(sql)).toBe(sql);
  });

  it("quita el byte nulo y los caracteres de control", () => {
    expect(limpiarTexto("Ram\u0000pa\u0007\u001b[31m")).toBe("Rampa[31m");
  });

  it("quita los caracteres invisibles y los que invierten el texto", () => {
    expect(limpiarTexto("Ram​pa‮gnp.exe﻿")).toBe("Rampagnp.exe");
  });

  it("une las letras con acento escritas en dos partes (NFC)", () => {
    const separada = "Señalización";
    expect(limpiarTexto(separada)).toBe("Señalización");
    expect(limpiarTexto(separada).length).toBe("Señalización".length);
  });

  it("conserva los saltos de línea y los tabuladores en un texto de varias líneas", () => {
    expect(limpiarTexto("Línea 1\r\nLínea 2\n\tsangría")).toBe("Línea 1\nLínea 2\n\tsangría");
  });

  it("en una sola línea cambia los saltos por un espacio", () => {
    expect(limpiarTexto("Rampa\nrota\r\nnorte", { multilinea: false })).toBe("Rampa rota norte");
  });

  it("respeta los emojis y los acentos", () => {
    expect(limpiarTexto("Baño sin rampa ♿ 😡")).toBe("Baño sin rampa ♿ 😡");
  });

  it("es idempotente", () => {
    const sucio = "<b>Ram​pa</b>\u0000 <script>x</script>";
    expect(limpiarTexto(limpiarTexto(sucio))).toBe(limpiarTexto(sucio));
  });
});

describe("sanitizarValor", () => {
  afterEach(() => {
    // Por si una prueba fallara a la mitad, que no contamine a las demás
    delete (Object.prototype as Record<string, unknown>).esAdmin;
  });

  it("limpia los textos de objetos y arreglos anidados", () => {
    expect(sanitizarValor({ a: "<b>x</b>", b: ["<i>y</i>", 3, true, null], c: { d: "z\u0000" } })).toEqual({
      a: "x",
      b: ["y", 3, true, null],
      c: { d: "z" },
    });
  });

  it("no limpia las contraseñas", () => {
    const body = { contrasena_usuario: "<b>Mi clave\u0000 segura</b>", contrasena_nueva: " con espacios " };
    expect(sanitizarValor(body)).toEqual(body);
  });

  it("descarta __proto__, constructor y prototype y no contamina los objetos", () => {
    const body = JSON.parse('{"titulo":"ok","__proto__":{"esAdmin":true},"constructor":{"prototype":{"esAdmin":true}}}');
    const limpio = sanitizarValor(body) as Record<string, unknown>;
    expect(Object.keys(limpio)).toEqual(["titulo"]);
    expect(({} as Record<string, unknown>).esAdmin).toBeUndefined();
    expect(Object.getPrototypeOf(limpio)).toBe(Object.prototype);
  });

  it("no modifica el objeto original", () => {
    const original = { titulo: "<b>x</b>" };
    sanitizarValor(original);
    expect(original.titulo).toBe("<b>x</b>");
  });
});

describe("middleware sanitizar", () => {
  it("limpia el cuerpo antes de que llegue a la ruta", async () => {
    const res = await request(crearApp())
      .post("/eco")
      .send({ titulo_reporte: "<script>alert(1)</script>Rampa", contrasena_usuario: "<no-se-toca>" });
    expect(res.body.body).toEqual({ titulo_reporte: "alert(1)Rampa", contrasena_usuario: "<no-se-toca>" });
  });

  it("deja pasar una petición sin cuerpo", async () => {
    const res = await request(crearApp()).post("/eco");
    expect(res.status).toBe(200);
  });

  it(`rechaza un JSON con más de ${PROFUNDIDAD_MAXIMA} niveles con 400 VALIDACION`, async () => {
    let anidado: unknown = "fondo";
    for (let i = 0; i < PROFUNDIDAD_MAXIMA + 1; i++) anidado = { a: anidado };
    const res = await request(crearApp()).post("/eco").send(anidado as object);
    expect(res.status).toBe(400);
    expect(res.body.error.codigo).toBe("VALIDACION");
  });

  it(`acepta exactamente ${PROFUNDIDAD_MAXIMA} niveles`, async () => {
    let anidado: unknown = "fondo";
    for (let i = 0; i < PROFUNDIDAD_MAXIMA; i++) anidado = { a: anidado };
    expect((await request(crearApp()).post("/eco").send(anidado as object)).status).toBe(200);
  });

  it("un __proto__ en el JSON no llega a la ruta ni contamina los objetos", async () => {
    const res = await request(crearApp())
      .post("/eco")
      .set("Content-Type", "application/json")
      .send('{"nombre":"Ana","__proto__":{"esAdmin":true}}');
    expect(res.body.body).toEqual({ nombre: "Ana" });
    expect(({} as Record<string, unknown>).esAdmin).toBeUndefined();
  });
});
