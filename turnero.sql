-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 12-05-2025 a las 17:35:51
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `turnero`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `GetAllClasses` ()   BEGIN
    SELECT 
        c.id_clase,
        c.id_disciplina,
        d.disciplina AS disciplina,
        c.id_dia,
        di.dia AS dia,
        c.hora,
        c.capacidad_max,
        c.disponibles
    FROM clases c
    JOIN disciplinas d ON c.id_disciplina = d.id_disciplina
    JOIN dias di ON c.id_dia = di.id_dia;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetClassesByUser` (IN `p_id_usuario` INT)   BEGIN
    DECLARE v_id_plan INT;

    -- Obtener el id_plan de la ultima cuota paga del usuario
    SELECT id_plan INTO v_id_plan
    FROM cuotas
    WHERE id_usuario = p_id_usuario AND estado_pago = 'Paga'
    ORDER BY fecha_pago DESC
    LIMIT 1;

    -- Devolver las clases correspondientes a las disciplinas del plan
    SELECT c.*
    FROM clases c
    JOIN planes_disciplinas pd ON c.id_disciplina = pd.id_disciplina
    WHERE pd.id_plan = v_id_plan;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetUserByEmail` (IN `p_email` VARCHAR(255))   BEGIN
    SELECT * FROM usuarios WHERE email = p_email;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterClient` (IN `p_email` VARCHAR(255), IN `p_password` VARCHAR(255), IN `p_nombre` VARCHAR(255), IN `p_dni` VARCHAR(20), IN `p_celular` VARCHAR(10))   BEGIN
    DECLARE new_user_id INT;


    INSERT INTO usuarios (email, password, nombre, id_rol, id_estado)
    VALUES (p_email, p_password, p_nombre, 3, 2);

    SET new_user_id = LAST_INSERT_ID();


    INSERT INTO datos_personales (id_usuario, dni, celular)
    VALUES (new_user_id, p_dni, p_celular);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterToClass` (IN `p_id_usuario` INT, IN `p_id_clase` INT)   BEGIN
    DECLARE v_creditos INT;
    DECLARE v_disponibles INT;
    DECLARE v_estado_usuario INT;
    DECLARE v_id_cuota INT;

    -- Verificar si el usuario está activo
    SELECT id_estado INTO v_estado_usuario
    FROM usuarios
    WHERE id_usuario = p_id_usuario;

    IF v_estado_usuario != 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario no está activo.';
    END IF;

    -- Obtener cuota más reciente con créditos
    SELECT id_cuota, creditos_disponibles INTO v_id_cuota, v_creditos
    FROM cuotas
    WHERE id_usuario = p_id_usuario
      AND creditos_disponibles > 0
    ORDER BY fecha_pago DESC
    LIMIT 1;

    IF v_creditos IS NULL OR v_creditos <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay créditos disponibles.';
    END IF;

    -- Verificar si la clase tiene disponibles
    SELECT disponibles INTO v_disponibles
    FROM clases
    WHERE id_clase = p_id_clase;

    IF v_disponibles <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay cupos disponibles en esta clase.';
    END IF;

    -- Insertar en la tabla intermedia
    INSERT INTO clases_usuarios (id_clase, id_usuario)
    VALUES (p_id_clase, p_id_usuario);

    -- Descontar crédito en cuota
    UPDATE cuotas
    SET creditos_disponibles = creditos_disponibles - 1
    WHERE id_cuota = v_id_cuota;

    -- Descontar disponible en clase
    UPDATE clases
    SET disponibles = disponibles - 1
    WHERE id_clase = p_id_clase;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterUser` (IN `p_email` VARCHAR(255), IN `p_password` VARCHAR(255), IN `p_nombre` VARCHAR(100), IN `p_dni` VARCHAR(20), IN `p_celular` VARCHAR(20), IN `p_id_rol` INT)   BEGIN
    DECLARE new_user_id INT;

    INSERT INTO usuarios (email, password, nombre, id_rol, id_estado)
    VALUES (p_email, p_password, p_nombre, p_id_rol, 1);

    SET new_user_id = LAST_INSERT_ID();

    INSERT INTO datos_personales (id_usuario, dni, celular)
    VALUES (new_user_id, p_dni, p_celular);
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clases`
--

CREATE TABLE `clases` (
  `id_clase` int(11) NOT NULL,
  `id_disciplina` int(11) DEFAULT NULL,
  `id_dia` int(11) DEFAULT NULL,
  `hora` time DEFAULT NULL,
  `capacidad_max` int(11) DEFAULT NULL,
  `disponibles` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `clases`
--

INSERT INTO `clases` (`id_clase`, `id_disciplina`, `id_dia`, `hora`, `capacidad_max`, `disponibles`) VALUES
(1, 1, 1, '08:00:00', 20, 19),
(2, 1, 2, '08:00:00', 20, 19),
(3, 1, 3, '08:00:00', 20, 20),
(4, 1, 4, '08:00:00', 20, 20),
(5, 1, 5, '08:00:00', 20, 20),
(6, 1, 6, '08:00:00', 20, 20),
(7, 2, 1, '09:00:00', 20, 20),
(8, 2, 2, '09:00:00', 20, 20),
(9, 2, 3, '09:00:00', 20, 20),
(10, 2, 4, '09:00:00', 20, 20),
(11, 2, 5, '09:00:00', 20, 20),
(12, 2, 6, '09:00:00', 20, 20),
(13, 3, 1, '10:00:00', 20, 20),
(14, 3, 2, '10:00:00', 20, 20),
(15, 3, 3, '10:00:00', 20, 20),
(16, 3, 4, '10:00:00', 20, 20),
(17, 3, 5, '10:00:00', 20, 20),
(18, 3, 6, '10:00:00', 20, 20),
(19, 4, 1, '11:00:00', 20, 20),
(20, 4, 2, '11:00:00', 20, 20),
(21, 4, 3, '11:00:00', 20, 20),
(22, 4, 4, '11:00:00', 20, 20),
(23, 4, 5, '11:00:00', 20, 20),
(24, 4, 6, '11:00:00', 20, 20),
(25, 5, 1, '12:00:00', 20, 20),
(26, 5, 2, '12:00:00', 20, 20),
(27, 5, 3, '12:00:00', 20, 20),
(28, 5, 4, '12:00:00', 20, 20),
(29, 5, 5, '12:00:00', 20, 20),
(30, 5, 6, '12:00:00', 20, 20);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clases_usuarios`
--

CREATE TABLE `clases_usuarios` (
  `id_clase` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `presente` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `clases_usuarios`
--

INSERT INTO `clases_usuarios` (`id_clase`, `id_usuario`, `presente`) VALUES
(1, 4, NULL),
(2, 4, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cuotas`
--

CREATE TABLE `cuotas` (
  `id_cuota` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `id_plan` int(11) NOT NULL,
  `fecha_pago` date DEFAULT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  `estado_pago` enum('Paga','Pendiente','Vencida') DEFAULT 'Paga',
  `creditos_total` int(11) NOT NULL,
  `creditos_disponibles` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `cuotas`
--

INSERT INTO `cuotas` (`id_cuota`, `id_usuario`, `id_plan`, `fecha_pago`, `fecha_vencimiento`, `estado_pago`, `creditos_total`, `creditos_disponibles`) VALUES
(1, 4, 1, '2025-05-12', '2025-06-11', 'Paga', 8, 6);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `datos_personales`
--

CREATE TABLE `datos_personales` (
  `id_usuario` int(11) NOT NULL,
  `dni` varchar(20) DEFAULT NULL,
  `celular` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `datos_personales`
--

INSERT INTO `datos_personales` (`id_usuario`, `dni`, `celular`) VALUES
(4, '46999888', '1133445566'),
(6, '41991328', '2364310386'),
(7, '41717495', '2364600084'),
(8, '345678495', '2345687964'),
(9, '37685437', '2364536786'),
(10, '34567685', '2364532432');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `dias`
--

CREATE TABLE `dias` (
  `id_dia` int(11) NOT NULL,
  `dia` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `dias`
--

INSERT INTO `dias` (`id_dia`, `dia`) VALUES
(1, 'Lunes'),
(2, 'Martes'),
(3, 'Miércoles'),
(4, 'Jueves'),
(5, 'Viernes'),
(6, 'Sábado');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `disciplinas`
--

CREATE TABLE `disciplinas` (
  `id_disciplina` int(11) NOT NULL,
  `disciplina` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `disciplinas`
--

INSERT INTO `disciplinas` (`id_disciplina`, `disciplina`) VALUES
(1, 'Crossfit'),
(2, 'Funcional'),
(3, 'Musculación'),
(4, 'Open box'),
(5, 'Levantamiento olímpico');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estados`
--

CREATE TABLE `estados` (
  `id_estado` int(11) NOT NULL,
  `estado` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `estados`
--

INSERT INTO `estados` (`id_estado`, `estado`) VALUES
(1, 'Activo'),
(2, 'Pausado'),
(3, 'Vencido');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `planes`
--

CREATE TABLE `planes` (
  `id_plan` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `monto` decimal(10,2) NOT NULL,
  `creditos_total` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `planes`
--

INSERT INTO `planes` (`id_plan`, `nombre`, `descripcion`, `monto`, `creditos_total`) VALUES
(1, 'Plan 8c multidisciplina', 'Permite asistir dos veces por semana a dos disciplinas', 20000.00, 8);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `planes_disciplinas`
--

CREATE TABLE `planes_disciplinas` (
  `id_plan` int(11) NOT NULL,
  `id_disciplina` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `planes_disciplinas`
--

INSERT INTO `planes_disciplinas` (`id_plan`, `id_disciplina`) VALUES
(1, 1),
(1, 2);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `roles`
--

CREATE TABLE `roles` (
  `id_rol` int(11) NOT NULL,
  `rol` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `roles`
--

INSERT INTO `roles` (`id_rol`, `rol`) VALUES
(1, 'Administrador'),
(2, 'Profesor'),
(3, 'Alumno');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` int(11) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `id_rol` int(11) DEFAULT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `id_estado` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `email`, `password`, `id_rol`, `nombre`, `id_estado`) VALUES
(4, 'lau@example.com', '$2b$10$JNw8UvDnif80vSmv1aCdqe0CJzLq.dZ5DyFagSAWUE2UGvPg6u9RS', 3, 'Lauti', 1),
(6, 'solsv7@gmail.com', '$2b$10$JucDwzLHnEQzABUNumPYf.IgNDbtqD9WfPm.K1l2A8ve5j8d35bny', 2, 'Sol', 1),
(7, 'ivomonti@gmail.com', '$2b$10$JY0E6Fs3l/t8YNp0LRU9n.urFfsF8RFYial53cg/BMTgNmAS565Du', 1, 'Ivo', 1),
(8, 'Ondinamonti@gmail.com', '$2b$10$q.27TtwF.1TE1JrEZ/b4dOxpbdfOAEBw.QsgxSjF1atSh/3Pk87OW', 1, 'Ondina', 1),
(9, 'flaviacalde@gmail.com', '$2b$10$0ughXdWBz5/305dM3U4sLu/DhvN0f4KmIynmWBItqp/ehXTQ1fhe.', 2, 'Flavia Calderon', 1),
(10, 'agusf@gmail.com', '$2b$10$puRGvIfbzdiNaYnVfI9BsuqS43MkyIa5XFH9b6IEduRjgupnFID.G', 3, 'Agustin Fernandez', 2);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `clases`
--
ALTER TABLE `clases`
  ADD PRIMARY KEY (`id_clase`),
  ADD KEY `id_disciplina` (`id_disciplina`),
  ADD KEY `id_dia` (`id_dia`);

--
-- Indices de la tabla `clases_usuarios`
--
ALTER TABLE `clases_usuarios`
  ADD PRIMARY KEY (`id_clase`,`id_usuario`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `cuotas`
--
ALTER TABLE `cuotas`
  ADD PRIMARY KEY (`id_cuota`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_plan` (`id_plan`);

--
-- Indices de la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD PRIMARY KEY (`id_usuario`);

--
-- Indices de la tabla `dias`
--
ALTER TABLE `dias`
  ADD PRIMARY KEY (`id_dia`);

--
-- Indices de la tabla `disciplinas`
--
ALTER TABLE `disciplinas`
  ADD PRIMARY KEY (`id_disciplina`);

--
-- Indices de la tabla `estados`
--
ALTER TABLE `estados`
  ADD PRIMARY KEY (`id_estado`);

--
-- Indices de la tabla `planes`
--
ALTER TABLE `planes`
  ADD PRIMARY KEY (`id_plan`);

--
-- Indices de la tabla `planes_disciplinas`
--
ALTER TABLE `planes_disciplinas`
  ADD PRIMARY KEY (`id_plan`,`id_disciplina`),
  ADD KEY `id_disciplina` (`id_disciplina`);

--
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id_rol`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD KEY `fk_usuario_rol` (`id_rol`),
  ADD KEY `fk_usuario_estado` (`id_estado`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `clases`
--
ALTER TABLE `clases`
  MODIFY `id_clase` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT de la tabla `cuotas`
--
ALTER TABLE `cuotas`
  MODIFY `id_cuota` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `dias`
--
ALTER TABLE `dias`
  MODIFY `id_dia` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `disciplinas`
--
ALTER TABLE `disciplinas`
  MODIFY `id_disciplina` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `estados`
--
ALTER TABLE `estados`
  MODIFY `id_estado` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `planes`
--
ALTER TABLE `planes`
  MODIFY `id_plan` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `id_rol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `clases`
--
ALTER TABLE `clases`
  ADD CONSTRAINT `clases_ibfk_1` FOREIGN KEY (`id_disciplina`) REFERENCES `disciplinas` (`id_disciplina`),
  ADD CONSTRAINT `clases_ibfk_2` FOREIGN KEY (`id_dia`) REFERENCES `dias` (`id_dia`);

--
-- Filtros para la tabla `clases_usuarios`
--
ALTER TABLE `clases_usuarios`
  ADD CONSTRAINT `clases_usuarios_ibfk_1` FOREIGN KEY (`id_clase`) REFERENCES `clases` (`id_clase`),
  ADD CONSTRAINT `clases_usuarios_ibfk_2` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Filtros para la tabla `cuotas`
--
ALTER TABLE `cuotas`
  ADD CONSTRAINT `cuotas_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `cuotas_ibfk_2` FOREIGN KEY (`id_plan`) REFERENCES `planes` (`id_plan`);

--
-- Filtros para la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD CONSTRAINT `datos_personales_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Filtros para la tabla `planes_disciplinas`
--
ALTER TABLE `planes_disciplinas`
  ADD CONSTRAINT `planes_disciplinas_ibfk_1` FOREIGN KEY (`id_plan`) REFERENCES `planes` (`id_plan`),
  ADD CONSTRAINT `planes_disciplinas_ibfk_2` FOREIGN KEY (`id_disciplina`) REFERENCES `disciplinas` (`id_disciplina`);

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `fk_usuario_estado` FOREIGN KEY (`id_estado`) REFERENCES `estados` (`id_estado`),
  ADD CONSTRAINT `fk_usuario_rol` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`),
  ADD CONSTRAINT `fk_usuarios_estado` FOREIGN KEY (`id_estado`) REFERENCES `estados` (`id_estado`),
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
