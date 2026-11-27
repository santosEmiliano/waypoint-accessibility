# Acceso al servidor

El backend y la BD viven en un droplet de DigitalOcean (ver `docs/despliegue-bd.md`). Para entrar se usa una **llave SSH personal**: cada quien tiene la suya y nadie comparte contraseñas.

Una llave SSH son dos archivos:

| Archivo | Qué es | ¿Se comparte? |
|---|---|---|
| `id_ed25519.pub` | La llave **pública**. Se pone en el servidor para dejarte entrar | Sí, a Julián |
| `id_ed25519` (sin `.pub`) | La llave **privada**. Es la que prueba que eres tú | **Nunca**, a nadie |

## 1. Crear tu llave

Abre una terminal (en Windows, **PowerShell**; en Mac o Linux, **Terminal**) y corre:

```bash
ssh-keygen -t ed25519
```

- Si pregunta dónde guardarla, da **Enter** (la deja en la carpeta `.ssh` de tu usuario).
- Si dice que ya existe (`already exists. Overwrite?`), escribe **n**: ya tienes una y sirve esa.
- La frase de seguridad (`passphrase`) es opcional. Si pones una, te la pedirá cada vez que entres.

## 2. Copiar tu llave pública

**Windows (PowerShell):**

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

**Mac o Linux:**

```bash
cat ~/.ssh/id_ed25519.pub
```

Sale una sola línea parecida a esta:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...muchas letras... tu-usuario@tu-compu
```

## 3. Mandársela a Julián

Copia **la línea completa** y mándasela por privado (WhatsApp, Discord). Es la pública, así que no pasa nada si alguien más la ve.

Julián la agrega al servidor y te avisa con la IP.

## 4. Entrar

```bash
ssh root@IP_DEL_SERVIDOR
```

La primera vez pregunta si confías en el servidor (`Are you sure you want to continue connecting?`): escribe `yes`. Si ves algo como `root@waypoint:~#`, ya estás dentro. Para salir: `exit`.

**Para ver la BD en MySQL Workbench**, abre un túnel en una terminal y déjala abierta:

```bash
ssh -N -L 3307:127.0.0.1:3306 root@IP_DEL_SERVIDOR
```

En Workbench conéctate a `127.0.0.1`, puerto `3307`. El usuario y la contraseña de la BD te los pasa Julián por privado.

## Cuidado

- Entras como `root`: puedes borrar todo con un comando. Si no sabes qué hace algo, pregunta antes.
- **Nunca** corras `docker compose down -v`: borra la BD completa.
- Si cambias de computadora o pierdes la llave, crea una nueva y manda la nueva pública. Julián quita la anterior.
