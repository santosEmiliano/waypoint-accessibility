-- CreateTable
CREATE TABLE `roles` (
    `id_rol` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `nombre_rol` VARCHAR(50) NOT NULL,

    UNIQUE INDEX `nombre_rol_UNIQUE`(`nombre_rol`),
    PRIMARY KEY (`id_rol`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `usuarios` (
    `id_usuario` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
    `nombre_usuario` VARCHAR(100) NOT NULL,
    `correo_usuario` VARCHAR(200) NOT NULL,
    `contrasena_usuario` VARCHAR(255) NOT NULL,
    `id_rol` TINYINT UNSIGNED NOT NULL,
    `creacion_usuario` DATETIME(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `actualizacion_usuario` DATETIME(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    UNIQUE INDEX `correo_usuario_UNIQUE`(`correo_usuario`),
    INDEX `fk_usuarios_rol_idx`(`id_rol`),
    PRIMARY KEY (`id_usuario`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `categorias` (
    `id_categoria` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `nombre_categoria` VARCHAR(100) NOT NULL,

    UNIQUE INDEX `nombre_categoria_UNIQUE`(`nombre_categoria`),
    PRIMARY KEY (`id_categoria`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `estados` (
    `id_estado` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `nombre_estado` VARCHAR(50) NOT NULL,
    `orden_estado` TINYINT UNSIGNED NOT NULL,

    UNIQUE INDEX `nombre_estado_UNIQUE`(`nombre_estado`),
    UNIQUE INDEX `orden_estado_UNIQUE`(`orden_estado`),
    PRIMARY KEY (`id_estado`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `reportes` (
    `id_reporte` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
    `id_usuario` INTEGER UNSIGNED NOT NULL,
    `id_operador` INTEGER UNSIGNED NULL,
    `id_categoria` TINYINT UNSIGNED NOT NULL,
    `id_estado` TINYINT UNSIGNED NOT NULL,
    `titulo_reporte` VARCHAR(200) NOT NULL,
    `descripcion_reporte` TEXT NOT NULL,
    `latitud_reporte` DECIMAL(9, 6) NULL,
    `longitud_reporte` DECIMAL(9, 6) NULL,
    `ubicacion_reporte` VARCHAR(255) NOT NULL,
    `cancelado_reporte` BOOLEAN NOT NULL DEFAULT false,
    `razon_cancelacion_reporte` TEXT NULL,
    `creacion_reporte` DATETIME(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `actualizacion_reporte` DATETIME(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `fk_reportes_usuario_idx`(`id_usuario`),
    INDEX `fk_reportes_operador_idx`(`id_operador`),
    INDEX `fk_reportes_categoria_idx`(`id_categoria`),
    INDEX `fk_reportes_estado_idx`(`id_estado`),
    PRIMARY KEY (`id_reporte`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `evidencias` (
    `id_evidencia` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
    `id_reporte` INTEGER UNSIGNED NOT NULL,
    `id_usuario` INTEGER UNSIGNED NOT NULL,
    `tipo_evidencia` ENUM('reporte', 'atencion') NOT NULL,
    `ruta_evidencia` VARCHAR(500) NOT NULL,
    `creacion_evidencia` DATETIME(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    UNIQUE INDEX `ruta_evidencia_UNIQUE`(`ruta_evidencia`),
    INDEX `fk_evidencias_reporte_idx`(`id_reporte`),
    INDEX `fk_evidencias_usuario_idx`(`id_usuario`),
    PRIMARY KEY (`id_evidencia`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `historial` (
    `id_historial` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
    `id_reporte` INTEGER UNSIGNED NOT NULL,
    `id_usuario` INTEGER UNSIGNED NOT NULL,
    `tipo_historial` ENUM('creacion', 'edicion', 'asignacion', 'cambio_estado', 'accion_correctiva', 'cancelacion') NOT NULL,
    `id_estado_anterior` TINYINT UNSIGNED NULL,
    `id_estado_nuevo` TINYINT UNSIGNED NULL,
    `descripcion_historial` TEXT NULL,
    `creacion_historial` DATETIME(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `fk_historial_reporte_idx`(`id_reporte`),
    INDEX `fk_historial_usuario_idx`(`id_usuario`),
    INDEX `fk_historial_estado_anterior_idx`(`id_estado_anterior`),
    INDEX `fk_historial_estado_nuevo_idx`(`id_estado_nuevo`),
    PRIMARY KEY (`id_historial`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `usuarios` ADD CONSTRAINT `fk_usuarios_rol` FOREIGN KEY (`id_rol`) REFERENCES `roles`(`id_rol`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `reportes` ADD CONSTRAINT `fk_reportes_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios`(`id_usuario`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `reportes` ADD CONSTRAINT `fk_reportes_operador` FOREIGN KEY (`id_operador`) REFERENCES `usuarios`(`id_usuario`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `reportes` ADD CONSTRAINT `fk_reportes_categoria` FOREIGN KEY (`id_categoria`) REFERENCES `categorias`(`id_categoria`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `reportes` ADD CONSTRAINT `fk_reportes_estado` FOREIGN KEY (`id_estado`) REFERENCES `estados`(`id_estado`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `evidencias` ADD CONSTRAINT `fk_evidencias_reporte` FOREIGN KEY (`id_reporte`) REFERENCES `reportes`(`id_reporte`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `evidencias` ADD CONSTRAINT `fk_evidencias_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios`(`id_usuario`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `historial` ADD CONSTRAINT `fk_historial_reporte` FOREIGN KEY (`id_reporte`) REFERENCES `reportes`(`id_reporte`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `historial` ADD CONSTRAINT `fk_historial_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios`(`id_usuario`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `historial` ADD CONSTRAINT `fk_historial_estado_anterior` FOREIGN KEY (`id_estado_anterior`) REFERENCES `estados`(`id_estado`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `historial` ADD CONSTRAINT `fk_historial_estado_nuevo` FOREIGN KEY (`id_estado_nuevo`) REFERENCES `estados`(`id_estado`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- CHECK agregados a mano (Prisma no los maneja en schema.prisma)

-- Solo hay 4 estados: Reportado (1), En análisis (2), En atención (3) y Resuelto (4)
ALTER TABLE `estados` ADD CONSTRAINT `chk_estados_orden` CHECK (`orden_estado` BETWEEN 1 AND 4);

-- Latitud y longitud van juntas: o vienen las dos o ninguna
ALTER TABLE `reportes` ADD CONSTRAINT `chk_reportes_coordenadas` CHECK ((`latitud_reporte` IS NULL) = (`longitud_reporte` IS NULL));

-- Solo un reporte cancelado puede tener razón de cancelación
ALTER TABLE `reportes` ADD CONSTRAINT `chk_reportes_razon_cancelacion` CHECK (`razon_cancelacion_reporte` IS NULL OR `cancelado_reporte` = 1);
