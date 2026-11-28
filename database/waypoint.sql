-- -----------------------------------------------------
-- Esquema final de la BD de Waypoint (MySQL 8.4)
-- -----------------------------------------------------
-- Es el mismo esquema que dejan las migraciones de Prisma (backend/prisma/migrations/):
-- esquema_inicial + revision_restricciones. Sirve para leer el modelo completo en un solo
-- archivo o para crear la BD sin Node.
--
-- La forma normal de crear la BD es con las migraciones (ver database/README.md):
--   cd backend && npm run db:deploy && npm run db:seed
-- Si se cambia schema.prisma o se agrega una migración, hay que actualizar este archivo.
--
-- Notas:
-- - `actualizacion_usuario` y `actualizacion_reporte` las pone al día Prisma (@updatedAt) en cada
--   UPDATE, no MySQL. Si se usa la BD sin Prisma, hay que actualizarlas a mano.
-- - Los datos iniciales (roles, categorías, estados y el operador de prueba) los carga la semilla
--   (backend/prisma/seed.ts), no este archivo.
-- - Qué revisa cada CHECK y por qué: docs/restricciones-bd.md.

-- Sin esto, algunos clientes mandan el script en latin1 y los textos de los CHECK cambian de juego de caracteres
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE SCHEMA IF NOT EXISTS `waypoint` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `waypoint`;

-- -----------------------------------------------------
-- roles: `usuario` y `operador`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `roles` (
  `id_rol` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre_rol` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`id_rol`),
  UNIQUE KEY `nombre_rol_UNIQUE` (`nombre_rol`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- usuarios. El correo no distingue mayúsculas (collation _ci) y la contraseña es un hash de bcrypt
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuarios` (
  `id_usuario` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre_usuario` VARCHAR(100) NOT NULL,
  `correo_usuario` VARCHAR(200) NOT NULL,
  `contrasena_usuario` VARCHAR(255) NOT NULL,
  `id_rol` TINYINT UNSIGNED NOT NULL,
  `creacion_usuario` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizacion_usuario` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `correo_usuario_UNIQUE` (`correo_usuario`),
  KEY `fk_usuarios_rol_idx` (`id_rol`),
  CONSTRAINT `fk_usuarios_rol` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_usuarios_nombre` CHECK (CHAR_LENGTH(TRIM(`nombre_usuario`)) > 0),
  CONSTRAINT `chk_usuarios_correo` CHECK (`correo_usuario` LIKE '%_@_%')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- categorias: tipos de barrera (rampa, elevador, señalización...)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `categorias` (
  `id_categoria` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre_categoria` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id_categoria`),
  UNIQUE KEY `nombre_categoria_UNIQUE` (`nombre_categoria`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- estados: los 4 pasos de un reporte, en orden (Reportado → En revisión → En proceso → Resuelto)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `estados` (
  `id_estado` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre_estado` VARCHAR(50) NOT NULL,
  `orden_estado` TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id_estado`),
  UNIQUE KEY `nombre_estado_UNIQUE` (`nombre_estado`),
  UNIQUE KEY `orden_estado_UNIQUE` (`orden_estado`),
  CONSTRAINT `chk_estados_orden` CHECK (`orden_estado` BETWEEN 1 AND 4)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- reportes. No se borran: se cancelan (cancelado_reporte = 1)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reportes` (
  `id_reporte` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_usuario` INT UNSIGNED NOT NULL,
  `id_operador` INT UNSIGNED NULL,
  `id_categoria` TINYINT UNSIGNED NOT NULL,
  `id_estado` TINYINT UNSIGNED NOT NULL,
  `titulo_reporte` VARCHAR(200) NOT NULL,
  `descripcion_reporte` TEXT NOT NULL,
  `latitud_reporte` DECIMAL(9,6) NULL,
  `longitud_reporte` DECIMAL(9,6) NULL,
  `ubicacion_reporte` VARCHAR(255) NOT NULL,
  `cancelado_reporte` TINYINT(1) NOT NULL DEFAULT 0,
  `razon_cancelacion_reporte` TEXT NULL,
  `creacion_reporte` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizacion_reporte` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_reporte`),
  KEY `fk_reportes_usuario_idx` (`id_usuario`),
  KEY `fk_reportes_operador_idx` (`id_operador`),
  KEY `fk_reportes_categoria_idx` (`id_categoria`),
  KEY `fk_reportes_estado_idx` (`id_estado`),
  CONSTRAINT `fk_reportes_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_reportes_operador` FOREIGN KEY (`id_operador`) REFERENCES `usuarios` (`id_usuario`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_reportes_categoria` FOREIGN KEY (`id_categoria`) REFERENCES `categorias` (`id_categoria`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_reportes_estado` FOREIGN KEY (`id_estado`) REFERENCES `estados` (`id_estado`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  -- La latitud y la longitud van juntas, y dentro del rango real
  CONSTRAINT `chk_reportes_coordenadas` CHECK ((`latitud_reporte` IS NULL) = (`longitud_reporte` IS NULL)),
  CONSTRAINT `chk_reportes_latitud` CHECK (`latitud_reporte` BETWEEN -90 AND 90),
  CONSTRAINT `chk_reportes_longitud` CHECK (`longitud_reporte` BETWEEN -180 AND 180),
  -- Textos sin vacíos ni solo espacios
  CONSTRAINT `chk_reportes_titulo` CHECK (CHAR_LENGTH(TRIM(`titulo_reporte`)) > 0),
  CONSTRAINT `chk_reportes_descripcion` CHECK (CHAR_LENGTH(TRIM(`descripcion_reporte`)) > 0),
  CONSTRAINT `chk_reportes_ubicacion` CHECK (CHAR_LENGTH(TRIM(`ubicacion_reporte`)) > 0),
  -- La razón de cancelación solo en un reporte cancelado
  CONSTRAINT `chk_reportes_razon_cancelacion` CHECK (`razon_cancelacion_reporte` IS NULL OR `cancelado_reporte` = 1)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- evidencias: fotos del reporte (`reporte`) y de la atención (`atencion`). No se borran
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `evidencias` (
  `id_evidencia` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_reporte` INT UNSIGNED NOT NULL,
  `id_usuario` INT UNSIGNED NOT NULL,
  `tipo_evidencia` ENUM('reporte', 'atencion') NOT NULL,
  `ruta_evidencia` VARCHAR(500) NOT NULL,
  `creacion_evidencia` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_evidencia`),
  UNIQUE KEY `ruta_evidencia_UNIQUE` (`ruta_evidencia`),
  KEY `fk_evidencias_reporte_idx` (`id_reporte`),
  KEY `fk_evidencias_usuario_idx` (`id_usuario`),
  CONSTRAINT `fk_evidencias_reporte` FOREIGN KEY (`id_reporte`) REFERENCES `reportes` (`id_reporte`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_evidencias_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_evidencias_ruta` CHECK (CHAR_LENGTH(TRIM(`ruta_evidencia`)) > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- historial: cada movimiento de un reporte. No se modifica ni se borra
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `historial` (
  `id_historial` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_reporte` INT UNSIGNED NOT NULL,
  `id_usuario` INT UNSIGNED NOT NULL,
  `tipo_historial` ENUM('creacion', 'edicion', 'asignacion', 'cambio_estado', 'accion_correctiva', 'cancelacion') NOT NULL,
  `id_estado_anterior` TINYINT UNSIGNED NULL,
  `id_estado_nuevo` TINYINT UNSIGNED NULL,
  `descripcion_historial` TEXT NULL,
  `creacion_historial` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_historial`),
  KEY `fk_historial_reporte_idx` (`id_reporte`),
  KEY `fk_historial_usuario_idx` (`id_usuario`),
  KEY `fk_historial_estado_anterior_idx` (`id_estado_anterior`),
  KEY `fk_historial_estado_nuevo_idx` (`id_estado_nuevo`),
  CONSTRAINT `fk_historial_reporte` FOREIGN KEY (`id_reporte`) REFERENCES `reportes` (`id_reporte`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_historial_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  -- ON UPDATE RESTRICT: MySQL no deja usar en un CHECK una columna con acción en cascada
  CONSTRAINT `fk_historial_estado_anterior` FOREIGN KEY (`id_estado_anterior`) REFERENCES `estados` (`id_estado`)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_historial_estado_nuevo` FOREIGN KEY (`id_estado_nuevo`) REFERENCES `estados` (`id_estado`)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  -- creacion: solo el estado nuevo; cambio_estado: los dos y distintos; los demás tipos: ninguno
  CONSTRAINT `chk_historial_estados` CHECK (
    (`tipo_historial` = 'creacion' AND `id_estado_anterior` IS NULL AND `id_estado_nuevo` IS NOT NULL)
    OR (`tipo_historial` = 'cambio_estado' AND `id_estado_anterior` IS NOT NULL AND `id_estado_nuevo` IS NOT NULL
        AND `id_estado_anterior` <> `id_estado_nuevo`)
    OR (`tipo_historial` NOT IN ('creacion', 'cambio_estado') AND `id_estado_anterior` IS NULL AND `id_estado_nuevo` IS NULL)
  ),
  -- Una acción correctiva siempre lleva descripción
  CONSTRAINT `chk_historial_accion_descripcion` CHECK (
    `tipo_historial` <> 'accion_correctiva'
    OR (`descripcion_historial` IS NOT NULL AND CHAR_LENGTH(TRIM(`descripcion_historial`)) > 0)
  )
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
