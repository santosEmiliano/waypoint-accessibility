# Waypoint: frontend

Aplicación Flutter de Waypoint, el sistema de reportes de accesibilidad universitaria. Corre en navegador, iPhone y escritorio (macOS). Consume la API REST del backend.

Responsable: Santos.

## Requisitos

- Flutter con Dart 3.13 o superior (`flutter --version`).
- Para iPhone y macOS: Xcode y una cuenta de Apple para firmar la app.
- Para la versión web: Google Chrome.

## Cómo ejecutarla

Desde esta carpeta (`frontend/`):

```
flutter pub get
flutter run -d chrome     # navegador
flutter run -d macos      # escritorio en macOS
flutter devices           # lista los dispositivos conectados
flutter run -d <id>       # iPhone físico, con el id que muestre el comando anterior
```

La dirección de la API aún no está configurada pero se documentará aquí cuando existan los servicios.

## Pruebas y análisis

```
flutter analyze
flutter test
```

## Estructura de `lib/`

El código se organiza por capas, con responsabilidades separadas:

| Carpeta | Contenido |
|---|---|
| `pantallas/` | Las pantallas de la app: inicio de sesión, principal, listado, detalle, formulario, administración y perfil |
| `componentes/` | Widgets reutilizables que usan varias pantallas |
| `servicios/` | Comunicación con la API (cliente HTTP y repositorios) y acceso a cámara, ubicación y sensores |
| `proveedores/` | Estado de la aplicación con Provider (sesión, lista de reportes, etc.) |
| `modelos/` | Clases de datos: Reporte, Usuario, Evidencia, Historial |
| `rutas/` | Navegación entre pantallas |
| `tema/` | Colores, tipografía y estilos |
| `utilidades/` | Validadores, formateo de fechas y constantes |

Archivos en la raíz de `lib/`:

- `main.dart`: inicio de la aplicación.
- `aplicacion.dart`: widget raíz `AplicacionWaypoint`, donde se conectan el tema, las rutas y los proveedores.