// Qué acepta cada ruta. Las reglas son las de docs/api.md y los límites son los de las columnas de la BD.
// Uso: router.post("/reportes", autenticar, validar(esquemas.crearReporte), controlador)
import {
  booleano,
  contrasenaGuardada,
  contrasenaNueva,
  correo,
  decimal,
  entero,
  nulable,
  opcional,
  texto,
  unoDe,
  type Esquema,
  type ReglaCruzada,
  type Seccion,
} from "./validacion";
import type { OrdenReportes } from "../db/reportes";

// Máximos de las columnas: INT UNSIGNED para los reportes, TINYINT UNSIGNED para los catálogos
const MAX_INT_UNSIGNED = 4_294_967_295;
const MAX_TINYINT_UNSIGNED = 255;

const idReporte = entero({ max: MAX_INT_UNSIGNED });
const idCatalogo = entero({ max: MAX_TINYINT_UNSIGNED });

// La API pone este tope a los textos largos; la columna TEXT admite más (ver docs/api.md)
const TEXTO_LARGO = 2000;

// Texto que se busca en el título, la descripción o la ubicación
const busqueda = texto({ max: 100 });

// Máximo de reportes por página, para que nadie pida un millón de un golpe
const LIMITE_MAXIMO = 100;

// Los órdenes de listarReportes (db/reportes.ts). Se repiten aquí para no cargar la BD en la
// validación; `satisfies` avisa al compilar si dejan de coincidir.
const ORDENES_REPORTES = ["creacion", "actualizacion"] as const satisfies readonly OrdenReportes[];

// `/reportes/:id`
const paramsReporte: Seccion = { campos: { id: idReporte } };

// La latitud y la longitud van juntas: o vienen las dos o ninguna
type Errores = ReturnType<ReglaCruzada>;

const coordenadasJuntas: ReglaCruzada = ({ latitud_reporte: lat, longitud_reporte: lon }): Errores => {
  if ((lat === null) === (lon === null)) return null;
  return lat === null
    ? { latitud_reporte: "Va junto con la longitud" }
    : { longitud_reporte: "Va junto con la latitud" };
};

const cuerpoReporte: Seccion = {
  campos: {
    titulo_reporte: texto({ max: 200 }),
    descripcion_reporte: texto({ max: TEXTO_LARGO, multilinea: true }),
    id_categoria: idCatalogo,
    ubicacion_reporte: texto({ max: 255 }),
    latitud_reporte: nulable(decimal({ min: -90, max: 90, decimales: 6 })),
    longitud_reporte: nulable(decimal({ min: -180, max: 180, decimales: 6 })),
  },
  cruzadas: [coordenadasJuntas],
};

// Para cambiar la contraseña se mandan la actual y la nueva, y hay que mandar al menos un cambio
const cambiosDeUsuario: ReglaCruzada = (datos): Errores => {
  const actual = datos.contrasena_actual !== undefined;
  const nueva = datos.contrasena_nueva !== undefined;
  if (nueva && !actual) return { contrasena_actual: "Es obligatoria para cambiar la contraseña" };
  if (actual && !nueva) return { contrasena_nueva: "Es obligatoria para cambiar la contraseña" };
  if (!nueva && datos.nombre_usuario === undefined) {
    return { nombre_usuario: "Manda el nombre o la contraseña nueva" };
  }
  return null;
};

export const esquemas = {
  // POST /auth/registro. El rol no se acepta: la cuenta siempre nace como `usuario`
  registro: {
    body: {
      campos: {
        nombre_usuario: texto({ max: 100 }),
        correo_usuario: correo({ max: 200 }),
        contrasena_usuario: contrasenaNueva(),
      },
    },
  },

  // POST /auth/login
  login: {
    body: {
      campos: {
        correo_usuario: correo({ max: 200 }),
        contrasena_usuario: contrasenaGuardada(),
      },
    },
  },

  // PUT /auth/usuario. El correo y el rol no están: si vienen, se ignoran
  actualizarUsuario: {
    body: {
      campos: {
        nombre_usuario: opcional(texto({ max: 100 })),
        contrasena_actual: opcional(contrasenaGuardada()),
        contrasena_nueva: opcional(contrasenaNueva()),
      },
      cruzadas: [cambiosDeUsuario],
    },
  },

  // POST /reportes
  crearReporte: { body: cuerpoReporte },

  // GET /reportes?id_estado=&id_categoria=&q=&cancelados=&limite=&desde=&orden=
  // Sin `limite` devuelve todos; `desde` es cuántos saltarse (0 = la primera página)
  listarReportes: {
    query: {
      campos: {
        id_estado: opcional(idCatalogo),
        id_categoria: opcional(idCatalogo),
        q: opcional(busqueda),
        cancelados: opcional(booleano()),
        limite: opcional(entero({ max: LIMITE_MAXIMO })),
        desde: opcional(entero({ min: 0, max: MAX_INT_UNSIGNED })),
        orden: opcional(unoDe(ORDENES_REPORTES)),
      },
    },
  },

  // GET /reportes/resumen?id_categoria=&q=: los mismos filtros que el listado, menos el estado
  // (el resumen es el conteo por estado) y los cancelados (no se cuentan)
  resumenReportes: {
    query: {
      campos: {
        id_categoria: opcional(idCatalogo),
        q: opcional(busqueda),
      },
    },
  },

  // GET /reportes/:id, GET /reportes/:id/historial, GET y POST /reportes/:id/evidencias,
  // PATCH /reportes/:id/asignar
  idReporte: { params: paramsReporte },

  // PUT /reportes/:id: el reporte completo, con las mismas reglas que al crearlo
  editarReporte: { params: paramsReporte, body: cuerpoReporte },

  // PATCH /reportes/:id/cancelar. Sin razón se manda `{}`
  cancelarReporte: {
    params: paramsReporte,
    body: { campos: { razon_cancelacion_reporte: nulable(texto({ max: TEXTO_LARGO, multilinea: true })) } },
  },

  // PATCH /reportes/:id/estado
  cambiarEstado: {
    params: paramsReporte,
    body: {
      campos: {
        id_estado: idCatalogo,
        descripcion_historial: nulable(texto({ max: TEXTO_LARGO, multilinea: true })),
      },
    },
  },

  // POST /reportes/:id/acciones
  accionCorrectiva: {
    params: paramsReporte,
    body: { campos: { descripcion_historial: texto({ max: TEXTO_LARGO, multilinea: true }) } },
  },
} satisfies Record<string, Esquema>;
