import express from "express";
import request from "supertest";
import { describe, expect, it } from "vitest";
import { esquemas } from "../src/middlewares/esquemas";
import { sanitizar } from "../src/middlewares/sanitizacion";
import { decimal, entero, nulable, opcional, texto, validar } from "../src/middlewares/validacion";

// Una app con las rutas del contrato que solo devuelve lo que dejó la validación
function crearApp() {
  const app = express();
  app.use(express.json());
  app.use(sanitizar);
  const eco = (req: express.Request, res: express.Response) => {
    res.json({ validado: req.validado, body: req.body });
  };
  app.post("/auth/registro", validar(esquemas.registro), eco);
  app.post("/auth/login", validar(esquemas.login), eco);
  app.put("/auth/usuario", validar(esquemas.actualizarUsuario), eco);
  app.post("/reportes", validar(esquemas.crearReporte), eco);
  app.get("/reportes", validar(esquemas.listarReportes), eco);
  app.get("/reportes/resumen", validar(esquemas.resumenReportes), eco);
  app.get("/reportes/:id", validar(esquemas.idReporte), eco);
  app.put("/reportes/:id", validar(esquemas.editarReporte), eco);
  app.patch("/reportes/:id/cancelar", validar(esquemas.cancelarReporte), eco);
  app.patch("/reportes/:id/estado", validar(esquemas.cambiarEstado), eco);
  app.post("/reportes/:id/acciones", validar(esquemas.accionCorrectiva), eco);
  return app;
}

const app = crearApp();

const reporteValido = {
  titulo_reporte: "Rampa rota en el edificio 1",
  descripcion_reporte: "La rampa de la entrada norte tiene una grieta.",
  id_categoria: 1,
  ubicacion_reporte: "Edificio 1, entrada norte",
  latitud_reporte: 21.91356,
  longitud_reporte: -102.31502,
};

function esperarValidacion(res: request.Response, campos: Record<string, unknown>) {
  expect(res.status).toBe(400);
  expect(res.body.error.codigo).toBe("VALIDACION");
  expect(res.body.error.mensaje).toBeTypeOf("string");
  expect(res.body.error.campos).toMatchObject(campos);
}

describe("formato del error", () => {
  it("junta todos los campos con error en una sola respuesta, con el formato de docs/api.md", async () => {
    const res = await request(app).post("/auth/registro").send({});
    expect(res.status).toBe(400);
    expect(res.body).toEqual({
      error: {
        codigo: "VALIDACION",
        mensaje: "Hay campos inválidos",
        campos: {
          nombre_usuario: "Es obligatorio",
          correo_usuario: "Es obligatorio",
          contrasena_usuario: "Es obligatorio",
        },
      },
    });
  });

  it("rechaza un cuerpo que no es un objeto", async () => {
    const res = await request(app).post("/auth/login").send([{ correo_usuario: "a@a.com" }]);
    expect(res.status).toBe(400);
    expect(res.body.error.codigo).toBe("VALIDACION");
  });

  it("una petición sin cuerpo se trata como un objeto vacío", async () => {
    const res = await request(app).post("/auth/login");
    esperarValidacion(res, { correo_usuario: "Es obligatorio", contrasena_usuario: "Es obligatorio" });
  });
});

describe("registro y login", () => {
  it("acepta un registro válido, normaliza el correo y descarta el rol que se intente colar", async () => {
    const res = await request(app).post("/auth/registro").send({
      nombre_usuario: "  Ana López ",
      correo_usuario: " ANA@Ejemplo.com ",
      contrasena_usuario: "una-contraseña-segura",
      nombre_rol: "operador",
      id_rol: 2,
    });
    expect(res.status).toBe(200);
    expect(res.body.body).toEqual({
      nombre_usuario: "Ana López",
      correo_usuario: "ana@ejemplo.com",
      contrasena_usuario: "una-contraseña-segura",
    });
  });

  it.each(["ana", "ana@", "@ejemplo.com", "ana@ejemplo", "ana @ejemplo.com", "a".repeat(195) + "@x.com"])(
    "rechaza el correo %j",
    async (correo) => {
      const res = await request(app).post("/auth/login").send({ correo_usuario: correo, contrasena_usuario: "x" });
      esperarValidacion(res, { correo_usuario: "Formato inválido" });
    },
  );

  it("en el registro aplica las reglas de la contraseña (mínimo 8, máximo 72 bytes)", async () => {
    const corta = await request(app)
      .post("/auth/registro")
      .send({ nombre_usuario: "Ana", correo_usuario: "a@a.com", contrasena_usuario: "corta" });
    esperarValidacion(corta, { contrasena_usuario: expect.stringMatching(/al menos 8/) });

    const larga = await request(app)
      .post("/auth/registro")
      .send({ nombre_usuario: "Ana", correo_usuario: "a@a.com", contrasena_usuario: "ñ".repeat(40) });
    esperarValidacion(larga, { contrasena_usuario: expect.stringMatching(/72 bytes/) });
  });

  it("en el login no aplica el mínimo: solo pide que venga", async () => {
    const res = await request(app).post("/auth/login").send({ correo_usuario: "a@a.com", contrasena_usuario: "corta" });
    expect(res.status).toBe(200);
  });

  it("la contraseña no se recorta ni se limpia", async () => {
    const res = await request(app)
      .post("/auth/login")
      .send({ correo_usuario: "a@a.com", contrasena_usuario: "  <clave> con espacios  " });
    expect(res.body.body.contrasena_usuario).toBe("  <clave> con espacios  ");
  });

  it("rechaza tipos equivocados", async () => {
    const res = await request(app)
      .post("/auth/registro")
      .send({ nombre_usuario: 123, correo_usuario: ["a@a.com"], contrasena_usuario: { a: 1 } });
    esperarValidacion(res, {
      nombre_usuario: "Formato inválido",
      correo_usuario: "Formato inválido",
      contrasena_usuario: "Formato inválido",
    });
  });

  it("un nombre que solo trae etiquetas HTML queda vacío y es obligatorio", async () => {
    const res = await request(app)
      .post("/auth/registro")
      .send({ nombre_usuario: "<script></script>", correo_usuario: "a@a.com", contrasena_usuario: "Contrasena123" });
    esperarValidacion(res, { nombre_usuario: "Es obligatorio" });
  });
});

describe("PUT /auth/usuario", () => {
  it("acepta solo el nombre", async () => {
    const res = await request(app).put("/auth/usuario").send({ nombre_usuario: "Ana María" });
    expect(res.body.body).toEqual({ nombre_usuario: "Ana María" });
  });

  it("acepta cambiar la contraseña con la actual y la nueva, e ignora el correo y el rol", async () => {
    const res = await request(app).put("/auth/usuario").send({
      contrasena_actual: "vieja",
      contrasena_nueva: "Contrasena-nueva-1",
      correo_usuario: "otro@a.com",
      nombre_rol: "operador",
    });
    expect(res.body.body).toEqual({ contrasena_actual: "vieja", contrasena_nueva: "Contrasena-nueva-1" });
  });

  it("pide la contraseña actual si viene la nueva, y al revés", async () => {
    esperarValidacion(await request(app).put("/auth/usuario").send({ contrasena_nueva: "Contrasena-nueva-1" }), {
      contrasena_actual: expect.any(String),
    });
    esperarValidacion(await request(app).put("/auth/usuario").send({ contrasena_actual: "vieja" }), {
      contrasena_nueva: expect.any(String),
    });
  });

  it("sin ningún cambio responde 400", async () => {
    esperarValidacion(await request(app).put("/auth/usuario").send({ correo_usuario: "a@a.com" }), {
      nombre_usuario: expect.any(String),
    });
  });
});

describe("crear y editar reporte", () => {
  it("acepta un reporte válido y lo devuelve limpio", async () => {
    const res = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, titulo_reporte: "  <b>Rampa</b>\nrota  ", id_estado: 4, id_usuario: 99 });
    expect(res.status).toBe(200);
    expect(res.body.body).toEqual({ ...reporteValido, titulo_reporte: "Rampa rota" });
  });

  it("la descripción conserva los saltos de línea", async () => {
    const res = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, descripcion_reporte: "Línea 1\nLínea 2" });
    expect(res.body.body.descripcion_reporte).toBe("Línea 1\nLínea 2");
  });

  it("sin coordenadas quedan en null", async () => {
    const { latitud_reporte, longitud_reporte, ...sinCoordenadas } = reporteValido;
    const res = await request(app).post("/reportes").send(sinCoordenadas);
    expect(res.body.body).toMatchObject({ latitud_reporte: null, longitud_reporte: null });
  });

  it("la latitud y la longitud van juntas", async () => {
    esperarValidacion(await request(app).post("/reportes").send({ ...reporteValido, longitud_reporte: null }), {
      longitud_reporte: expect.any(String),
    });
    esperarValidacion(await request(app).post("/reportes").send({ ...reporteValido, latitud_reporte: undefined }), {
      latitud_reporte: expect.any(String),
    });
  });

  it.each([
    ["latitud_reporte", 90.5],
    ["latitud_reporte", -91],
    ["longitud_reporte", 180.000001],
    ["latitud_reporte", 21.1234567],
    ["latitud_reporte", "21.9"],
  ])("rechaza %s = %j", async (campo, valor) => {
    const res = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, [campo]: valor });
    expect(res.status).toBe(400);
    expect(res.body.error.campos).toHaveProperty(campo);
  });

  it("acepta los extremos del rango y 6 decimales", async () => {
    const res = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, latitud_reporte: -90, longitud_reporte: 179.999999 });
    expect(res.status).toBe(200);
  });

  it("los largos se cuentan como en MySQL: un emoji es un carácter", async () => {
    const justo = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, titulo_reporte: "😡".repeat(200) });
    expect(justo.status).toBe(200);
    const pasado = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, titulo_reporte: "a".repeat(201) });
    esperarValidacion(pasado, { titulo_reporte: "Máximo 200 caracteres" });
  });

  it("la descripción tiene tope de 2000 caracteres", async () => {
    const res = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, descripcion_reporte: "a".repeat(2001) });
    esperarValidacion(res, { descripcion_reporte: "Máximo 2000 caracteres" });
  });

  it.each([0, -1, 256, 1.5, "abc", true])("rechaza id_categoria = %j", async (id) => {
    const res = await request(app)
      .post("/reportes")
      .send({ ...reporteValido, id_categoria: id });
    esperarValidacion(res, { id_categoria: "Formato inválido" });
  });

  it("al editar valida también el id de la URL", async () => {
    const res = await request(app).put("/reportes/abc").send(reporteValido);
    esperarValidacion(res, { id: "Formato inválido" });
  });

  it("al editar, con todo bien, deja el id convertido a número", async () => {
    const res = await request(app).put("/reportes/7").send(reporteValido);
    expect(res.body.validado.params).toEqual({ id: 7 });
  });
});

describe("parámetro :id", () => {
  it.each(["abc", "0", "-1", "1.5", "1e3", "4294967296", "99999999999"])("rechaza /reportes/%s", async (id) => {
    const res = await request(app).get(`/reportes/${encodeURIComponent(id)}`);
    esperarValidacion(res, { id: expect.any(String) });
  });

  it("acepta el máximo de INT UNSIGNED", async () => {
    const res = await request(app).get("/reportes/4294967295");
    expect(res.body.validado.params).toEqual({ id: 4294967295 });
  });

  it("una inyección SQL en el id no pasa", async () => {
    const res = await request(app).get(`/reportes/${encodeURIComponent("7 OR 1=1")}`);
    expect(res.status).toBe(400);
  });
});

describe("GET /reportes (query)", () => {
  it("sin filtros deja la query vacía", async () => {
    const res = await request(app).get("/reportes");
    expect(res.body.validado.query).toEqual({});
  });

  it("convierte los filtros y los combina", async () => {
    const res = await request(app).get("/reportes?id_estado=2&id_categoria=3&q=%20rampa%20&cancelados=true&otro=x");
    expect(res.body.validado.query).toEqual({ id_estado: 2, id_categoria: 3, q: "rampa", cancelados: true });
  });

  it("un texto de búsqueda vacío o con solo espacios no filtra", async () => {
    const res = await request(app).get("/reportes?q=%20%20&id_estado=");
    expect(res.status).toBe(200);
    expect(res.body.validado.query).toEqual({});
  });

  it("limpia el texto de búsqueda", async () => {
    const res = await request(app).get(`/reportes?q=${encodeURIComponent("<script>x</script>rampa")}`);
    expect(res.body.validado.query.q).toBe("xrampa");
  });

  it.each([
    ["id_estado=abc", "id_estado"],
    ["id_estado=1&id_estado=2", "id_estado"],
    ["cancelados=si", "cancelados"],
    ["cancelados=1", "cancelados"],
    [`q=${"a".repeat(101)}`, "q"],
  ])("rechaza ?%s", async (query, campo) => {
    const res = await request(app).get(`/reportes?${query}`);
    expect(res.status).toBe(400);
    expect(res.body.error.campos).toHaveProperty(campo);
  });
});

describe("GET /reportes: paginación y orden", () => {
  it("convierte limite y desde a número y acepta los dos órdenes", async () => {
    const res = await request(app).get("/reportes?limite=10&desde=20&orden=actualizacion");
    expect(res.body.validado.query).toEqual({ limite: 10, desde: 20, orden: "actualizacion" });
    const porCreacion = await request(app).get("/reportes?orden=creacion");
    expect(porCreacion.body.validado.query).toEqual({ orden: "creacion" });
  });

  it("desde=0 es válido: es la primera página", async () => {
    const res = await request(app).get("/reportes?limite=10&desde=0");
    expect(res.status).toBe(200);
    expect(res.body.validado.query).toEqual({ limite: 10, desde: 0 });
  });

  it("sin limite, desde ni orden no se agregan (la función usa sus valores por defecto)", async () => {
    const res = await request(app).get("/reportes?limite=&orden=");
    expect(res.status).toBe(200);
    expect(res.body.validado.query).toEqual({});
  });

  it.each([
    ["limite=0", "limite"],
    ["limite=101", "limite"],
    ["limite=-5", "limite"],
    ["limite=diez", "limite"],
    ["desde=-1", "desde"],
    ["desde=1.5", "desde"],
    ["orden=fecha", "orden"],
    ["orden=CREACION", "orden"],
    ["orden=creacion&orden=actualizacion", "orden"],
  ])("rechaza ?%s", async (query, campo) => {
    const res = await request(app).get(`/reportes?${query}`);
    expect(res.status).toBe(400);
    expect(res.body.error.campos).toHaveProperty(campo);
  });

  it("el error del orden dice qué valores acepta", async () => {
    const res = await request(app).get("/reportes?orden=fecha");
    expect(res.body.error.campos.orden).toBe("Debe ser uno de: creacion, actualizacion");
  });
});

describe("GET /reportes/resumen (query)", () => {
  it("acepta la categoría y el texto, limpios", async () => {
    const res = await request(app).get("/reportes/resumen?id_categoria=2&q=%20rampa%20");
    expect(res.body.validado.query).toEqual({ id_categoria: 2, q: "rampa" });
  });

  it("ignora el estado, los cancelados y la paginación: no aplican al resumen", async () => {
    const res = await request(app).get("/reportes/resumen?id_estado=2&cancelados=true&limite=5");
    expect(res.status).toBe(200);
    expect(res.body.validado.query).toEqual({});
  });

  it.each([
    ["id_categoria=abc", "id_categoria"],
    [`q=${"a".repeat(101)}`, "q"],
  ])("rechaza ?%s", async (query, campo) => {
    const res = await request(app).get(`/reportes/resumen?${query}`);
    expect(res.status).toBe(400);
    expect(res.body.error.campos).toHaveProperty(campo);
  });
});

describe("cancelar, cambiar estado y acciones", () => {
  it("cancelar sin razón deja la razón en null", async () => {
    const res = await request(app).patch("/reportes/7/cancelar").send({});
    expect(res.body.body).toEqual({ razon_cancelacion_reporte: null });
  });

  it("cancelar sin cuerpo también funciona", async () => {
    const res = await request(app).patch("/reportes/7/cancelar");
    expect(res.status).toBe(200);
  });

  it("la razón tiene tope de 2000 caracteres", async () => {
    const res = await request(app)
      .patch("/reportes/7/cancelar")
      .send({ razon_cancelacion_reporte: "a".repeat(2001) });
    esperarValidacion(res, { razon_cancelacion_reporte: expect.any(String) });
  });

  it("cambiar estado pide id_estado y el comentario es opcional", async () => {
    esperarValidacion(await request(app).patch("/reportes/7/estado").send({}), { id_estado: "Es obligatorio" });
    const res = await request(app).patch("/reportes/7/estado").send({ id_estado: 2 });
    expect(res.body.body).toEqual({ id_estado: 2, descripcion_historial: null });
  });

  it("la acción correctiva pide la descripción", async () => {
    esperarValidacion(await request(app).post("/reportes/7/acciones").send({ descripcion_historial: "   " }), {
      descripcion_historial: "Es obligatorio",
    });
  });
});

describe("reglas sueltas", () => {
  it("opcional omite el campo y nulable lo deja en null", () => {
    expect(opcional(texto({ max: 5 }))(undefined)).toEqual({ ok: true, valor: undefined });
    expect(nulable(texto({ max: 5 }))("")).toEqual({ ok: true, valor: null });
  });

  it("opcional no esconde un error de formato", () => {
    expect(opcional(entero({ max: 9 }))("abc")).toEqual({ ok: false, error: "Formato inválido" });
  });

  it("entero acepta número o texto con dígitos", () => {
    expect(entero({ max: 9 })(7)).toEqual({ ok: true, valor: 7 });
    expect(entero({ max: 9 })("7")).toEqual({ ok: true, valor: 7 });
  });

  it("decimal no acepta NaN ni Infinity", () => {
    const regla = decimal({ min: -90, max: 90, decimales: 6 });
    expect(regla(Number.NaN).ok).toBe(false);
    expect(regla(Number.POSITIVE_INFINITY).ok).toBe(false);
  });
});
