# Waypoint

Sistema de reportes de accesibilidad universitaria. Permite a los usuarios reportar obstáculos o condiciones que dificultan el acceso a las instalaciones, con fotografía, categoría y ubicación, y a un operador analizarlos, atenderlos y darles seguimiento.

Proyecto final de **Programación de Dispositivos Móviles**, Universidad Autónoma de Aguascalientes, Ingeniería en Sistemas Computacionales, 7.º semestre.

## Cómo funciona

- El **usuario** registra un reporte con categoría, descripción, ubicación y fotografías, y consulta el avance y el historial de sus reportes.
- El **operador** consulta todos los reportes, los analiza, cambia su estado, documenta las acciones correctivas y sube la fotografía de la atención realizada.
- Cada reporte pasa por cuatro estados: **Reportado → En análisis → En atención → Resuelto**.
- **Regla del sistema:** un reporte no puede marcarse como Resuelto si no tiene al menos una evidencia fotográfica de la atención realizada.
- Los permisos se comprueban en el backend. Cada cambio de estado queda registrado en el historial.

## Arquitectura

1. **Flutter** (web, iPhone y escritorio) que consume la API.
2. **Servidor backend** con una API REST.
3. **Base de datos relacional central**, a la que solo accede el backend.

## Estructura del repositorio

| Carpeta | Contenido | Responsable |
|---|---|---|
| `frontend/` | Aplicación Flutter | Santos |
| `backend/` | API REST y controladores | Harim |
| `database/` | Scripts SQL, semillas y configuración de la BD | Julián |
| `docs/` | Diagrama entidad-relación, contrato de la API, funciones de acceso a datos | Los tres |
| `.github/` | Plantilla de Pull Request y Workflows | Los tres |

## Equipo

| Integrante | Usuario de GitHub | Parte |
|---|---|---|
| Emiliano Alejandro Santos González | `santosEmiliano` | Frontend y coordinación |
| Julián Emmanuel Hernández | `JulianHernandezEmma` | Base de datos y middlewares |
| Harim Jesús Enrique Dueñas Dávila | `HarimDuenas` | API |

## Cómo trabajamos

El seguimiento está en la pestaña **Projects** del repositorio, con las columnas Pendiente, En proceso, En revisión y Terminado. Cada actividad es un Issue con responsable, criterios de aceptación y etiqueta, y pertenece a un hito que corresponde a un día de trabajo.

### Ramas

No se desarrolla directamente sobre `main`. Cada Issue se trabaja en su propia rama:

```
feature/<tema>   nueva funcionalidad
fix/<tema>       corrección de un error
docs/<tema>      documentación
chore/<tema>     configuración y mantenimiento
```

### Pull Requests

- Un Pull Request por Issue, de tamaño pequeño, con descripción y el Issue relacionado.
- **Revisión cruzada obligatoria:** Julián revisa a Harim, Harim revisa a Santos y Santos revisa a Julián.
- Nadie integra su propio Pull Request sin la aprobación de su compañero.
- Un Issue está terminado cuando funciona, su Pull Request fue aprobado e integrado, y el Issue pasó a la columna Terminado.

## Cómo ejecutar el proyecto

Cada parte documenta aquí su instalación y ejecución cuando queda lista.

- **Base de datos:** pendiente (Julián).
- **Backend:** pendiente (Harim).
- **Frontend:** pendiente (Santos).

Variables de entorno: copiar `.env.example` a `.env` y completar los valores.

## Documentación técnica

Se agrega en `docs/` conforme avanza el proyecto:

- Diagrama entidad-relación (Julián).
- Contrato de la API (Harim).
- Funciones de acceso a datos (Julián).
