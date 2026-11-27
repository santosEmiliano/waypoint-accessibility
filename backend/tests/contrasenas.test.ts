import { describe, expect, it } from "vitest";
import { hashearContrasena, validarContrasena, verificarContrasena } from "../src/auth/contrasenas";

describe("validarContrasena", () => {
  it("acepta una contraseña normal", () => {
    expect(validarContrasena("Contrasena123")).toBeNull();
  });
  it("rechaza menos de 8 caracteres", () => {
    expect(validarContrasena("corta")).toMatch(/al menos 8/);
  });
  it("rechaza lo que no es texto", () => {
    expect(validarContrasena(undefined)).not.toBeNull();
    expect(validarContrasena(12345678)).not.toBeNull();
  });
  it("rechaza más de 72 bytes, contando los acentos como más de uno", () => {
    expect(validarContrasena("a".repeat(72))).toBeNull();
    expect(validarContrasena("a".repeat(73))).not.toBeNull();
    expect(validarContrasena("ñ".repeat(37))).not.toBeNull();
  });
});

describe("hash", () => {
  it("el hash no es la contraseña y se puede verificar", async () => {
    const hash = await hashearContrasena("Contrasena123");
    expect(hash).not.toContain("Contrasena123");
    expect(hash.startsWith("$2")).toBe(true);
    expect(await verificarContrasena("Contrasena123", hash)).toBe(true);
    expect(await verificarContrasena("otra-cosa-123", hash)).toBe(false);
  });
  it("la misma contraseña da hashes distintos (sal)", async () => {
    expect(await hashearContrasena("Contrasena123")).not.toBe(await hashearContrasena("Contrasena123"));
  });
});
