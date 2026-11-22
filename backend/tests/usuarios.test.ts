import { beforeEach, describe, expect, it, vi } from "vitest";

// Se reemplaza el cliente de Prisma: así las pruebas no necesitan la BD levantada
const prisma = vi.hoisted(() => ({
  rol: { findUniqueOrThrow: vi.fn() },
  usuario: { create: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
}));
vi.mock("../src/db/prisma", () => ({ prisma }));

import {
  actualizarUsuario,
  buscarUsuarioPorCorreo,
  buscarUsuarioPorId,
  CorreoDuplicadoError,
  crearUsuario,
} from "../src/db/usuarios";

beforeEach(() => {
  vi.resetAllMocks();
  prisma.rol.findUniqueOrThrow.mockResolvedValue({ idRol: 1, nombreRol: "usuario" });
});

describe("crearUsuario", () => {
  it("crea con rol usuario, correo normalizado y sin pedir el hash de vuelta", async () => {
    prisma.usuario.create.mockResolvedValue({ idUsuario: 5 });
    await crearUsuario({ nombre: "  Ana  ", correo: "  ANA@Correo.COM ", contrasenaHash: "$2b$hash" });
    const llamada = prisma.usuario.create.mock.calls[0][0];
    expect(prisma.rol.findUniqueOrThrow).toHaveBeenCalledWith({ where: { nombreRol: "usuario" } });
    expect(llamada.data).toEqual({
      nombreUsuario: "Ana",
      correoUsuario: "ana@correo.com",
      contrasenaUsuario: "$2b$hash",
      idRol: 1,
    });
    expect(llamada.select).not.toHaveProperty("contrasenaUsuario");
  });

  it("convierte el UNIQUE de la BD (P2002) en CorreoDuplicadoError", async () => {
    prisma.usuario.create.mockRejectedValue({ code: "P2002" });
    await expect(crearUsuario({ nombre: "Ana", correo: "a@a.com", contrasenaHash: "h" })).rejects.toBeInstanceOf(
      CorreoDuplicadoError,
    );
  });

  it("deja pasar otros errores tal cual", async () => {
    const fallo = new Error("se cayó la BD");
    prisma.usuario.create.mockRejectedValue(fallo);
    await expect(crearUsuario({ nombre: "Ana", correo: "a@a.com", contrasenaHash: "h" })).rejects.toBe(fallo);
  });
});

describe("buscar", () => {
  it("por correo normaliza y es la única que pide el hash", async () => {
    prisma.usuario.findUnique.mockResolvedValue(null);
    expect(await buscarUsuarioPorCorreo(" Ana@Correo.com ")).toBeNull();
    const llamada = prisma.usuario.findUnique.mock.calls[0][0];
    expect(llamada.where).toEqual({ correoUsuario: "ana@correo.com" });
    expect(llamada.select.contrasenaUsuario).toBe(true);
  });

  it("por id no pide el hash", async () => {
    prisma.usuario.findUnique.mockResolvedValue({ idUsuario: 3 });
    await buscarUsuarioPorId(3);
    const llamada = prisma.usuario.findUnique.mock.calls[0][0];
    expect(llamada.where).toEqual({ idUsuario: 3 });
    expect(llamada.select).not.toHaveProperty("contrasenaUsuario");
  });
});

describe("actualizarUsuario", () => {
  it("solo escribe los campos que se mandan y nunca el correo ni el rol", async () => {
    prisma.usuario.update.mockResolvedValue({ idUsuario: 3 });
    await actualizarUsuario(3, { nombre: " Nuevo " });
    const llamada = prisma.usuario.update.mock.calls[0][0];
    expect(llamada.data).toEqual({ nombreUsuario: "Nuevo" });
    expect(llamada.select).not.toHaveProperty("contrasenaUsuario");
  });

  it("puede cambiar la contraseña (hash)", async () => {
    prisma.usuario.update.mockResolvedValue({ idUsuario: 3 });
    await actualizarUsuario(3, { contrasenaHash: "$2b$nuevo" });
    expect(prisma.usuario.update.mock.calls[0][0].data).toEqual({ contrasenaUsuario: "$2b$nuevo" });
  });

  it("sin cambios no escribe nada", async () => {
    prisma.usuario.findUnique.mockResolvedValue({ idUsuario: 3 });
    await actualizarUsuario(3, {});
    expect(prisma.usuario.update).not.toHaveBeenCalled();
  });

  it("devuelve null si el usuario no existe (P2025)", async () => {
    prisma.usuario.update.mockRejectedValue({ code: "P2025" });
    expect(await actualizarUsuario(99, { nombre: "X" })).toBeNull();
  });
});
