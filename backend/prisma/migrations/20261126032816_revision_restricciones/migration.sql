-- DropForeignKey
ALTER TABLE `historial` DROP FOREIGN KEY `fk_historial_estado_anterior`;

-- DropForeignKey
ALTER TABLE `historial` DROP FOREIGN KEY `fk_historial_estado_nuevo`;

-- AddForeignKey
ALTER TABLE `historial` ADD CONSTRAINT `fk_historial_estado_anterior` FOREIGN KEY (`id_estado_anterior`) REFERENCES `estados`(`id_estado`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `historial` ADD CONSTRAINT `fk_historial_estado_nuevo` FOREIGN KEY (`id_estado_nuevo`) REFERENCES `estados`(`id_estado`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Revisión de restricciones (#51): que la BD rechace por sí misma los datos inconsistentes,
-- aunque alguien se salte la API. Detalle y lo que queda en la API en docs/restricciones-bd.md.
--
-- Las dos llaves de arriba pasan de ON UPDATE CASCADE a RESTRICT porque MySQL no deja usar en un
-- CHECK una columna con acción referencial (ON UPDATE CASCADE). No cambia nada en la práctica:
-- el id de un estado nunca se modifica.

-- Coordenadas dentro del rango real (DECIMAL(9,6) aceptaría hasta ±999.999999)
ALTER TABLE `reportes` ADD CONSTRAINT `chk_reportes_latitud` CHECK (`latitud_reporte` BETWEEN -90 AND 90);
ALTER TABLE `reportes` ADD CONSTRAINT `chk_reportes_longitud` CHECK (`longitud_reporte` BETWEEN -180 AND 180);

-- Textos obligatorios que no pueden quedar vacíos ni con solo espacios
ALTER TABLE `reportes` ADD CONSTRAINT `chk_reportes_titulo` CHECK (CHAR_LENGTH(TRIM(`titulo_reporte`)) > 0);
ALTER TABLE `reportes` ADD CONSTRAINT `chk_reportes_descripcion` CHECK (CHAR_LENGTH(TRIM(`descripcion_reporte`)) > 0);
ALTER TABLE `reportes` ADD CONSTRAINT `chk_reportes_ubicacion` CHECK (CHAR_LENGTH(TRIM(`ubicacion_reporte`)) > 0);
ALTER TABLE `usuarios` ADD CONSTRAINT `chk_usuarios_nombre` CHECK (CHAR_LENGTH(TRIM(`nombre_usuario`)) > 0);
ALTER TABLE `evidencias` ADD CONSTRAINT `chk_evidencias_ruta` CHECK (CHAR_LENGTH(TRIM(`ruta_evidencia`)) > 0);

-- Un correo al menos tiene algo antes y después de la arroba (el formato completo lo valida la API)
ALTER TABLE `usuarios` ADD CONSTRAINT `chk_usuarios_correo` CHECK (`correo_usuario` LIKE '%_@_%');

-- Qué estados lleva cada tipo de movimiento del historial:
--   creacion: solo el estado nuevo (Reportado)
--   cambio_estado: los dos, y distintos
--   los demás (edicion, asignacion, accion_correctiva, cancelacion): ninguno
ALTER TABLE `historial` ADD CONSTRAINT `chk_historial_estados` CHECK (
  (`tipo_historial` = 'creacion' AND `id_estado_anterior` IS NULL AND `id_estado_nuevo` IS NOT NULL)
  OR (`tipo_historial` = 'cambio_estado' AND `id_estado_anterior` IS NOT NULL AND `id_estado_nuevo` IS NOT NULL
      AND `id_estado_anterior` <> `id_estado_nuevo`)
  OR (`tipo_historial` NOT IN ('creacion', 'cambio_estado') AND `id_estado_anterior` IS NULL AND `id_estado_nuevo` IS NULL)
);

-- Una acción correctiva sin descripción no documenta nada
ALTER TABLE `historial` ADD CONSTRAINT `chk_historial_accion_descripcion` CHECK (
  `tipo_historial` <> 'accion_correctiva'
  OR (`descripcion_historial` IS NOT NULL AND CHAR_LENGTH(TRIM(`descripcion_historial`)) > 0)
);
