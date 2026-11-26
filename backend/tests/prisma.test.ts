import { describe, expect, it } from "vitest";
import { opcionesAdaptador } from "../src/db/prisma";

describe("opcionesAdaptador", () => {
  it("separa DATABASE_URL en las opciones del adaptador", () => {
    expect(opcionesAdaptador("mysql://waypoint:a_b-1@127.0.0.1:3307/waypoint")).toMatchObject({
      host: "127.0.0.1",
      port: 3307,
      user: "waypoint",
      password: "a_b-1",
      database: "waypoint",
    });
  });

  it("si la BD no responde, la espera por una conexión es corta (3 s)", () => {
    expect(opcionesAdaptador("mysql://u:p@127.0.0.1/waypoint").acquireTimeout).toBe(3000);
  });

  it("sin puerto usa el 3306", () => {
    expect(opcionesAdaptador("mysql://u:p@localhost/waypoint").port).toBe(3306);
  });

  // MySQL 8 pide la llave RSA del servidor para mandar la contraseña sin TLS.
  // Solo se permite donde la contraseña no sale del servidor.
  it.each(["127.0.0.1", "localhost", "[::1]", "mysql"])("permite pedir la llave RSA contra %s", (host) => {
    expect(opcionesAdaptador(`mysql://u:p@${host}:3306/waypoint`).allowPublicKeyRetrieval).toBe(true);
  });

  it.each(["db.ejemplo.com", "203.0.113.10", "mysql.ejemplo.com"])("no la permite contra un host remoto (%s)", (host) => {
    expect(opcionesAdaptador(`mysql://u:p@${host}:3306/waypoint`).allowPublicKeyRetrieval).toBe(false);
  });
});
