-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 05-05-2025 a las 21:44:12
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

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clases_usuarios`
--

CREATE TABLE `clases_usuarios` (
  `id_clase` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `presente` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `creditos`
--

CREATE TABLE `creditos` (
  `id_credito` int(11) NOT NULL,
  `creditos` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cuotas`
--

CREATE TABLE `cuotas` (
  `id_cuota` int(11) NOT NULL,
  `id_disciplina` int(11) DEFAULT NULL,
  `id_credito` int(11) DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
(4, '46999888', '1133445566');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `dias`
--

CREATE TABLE `dias` (
  `id_dia` int(11) NOT NULL,
  `dia` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `disciplinas`
--

CREATE TABLE `disciplinas` (
  `id_disciplina` int(11) NOT NULL,
  `disciplina` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
(4, 'lau@example.com', '$2b$10$JNw8UvDnif80vSmv1aCdqe0CJzLq.dZ5DyFagSAWUE2UGvPg6u9RS', 3, 'Lauti', 2);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios_cuotas`
--

CREATE TABLE `usuarios_cuotas` (
  `id_usuario` int(11) NOT NULL,
  `id_cuota` int(11) NOT NULL,
  `fecha_inicio` date DEFAULT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  `creditos_disponibles` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
-- Indices de la tabla `creditos`
--
ALTER TABLE `creditos`
  ADD PRIMARY KEY (`id_credito`);

--
-- Indices de la tabla `cuotas`
--
ALTER TABLE `cuotas`
  ADD PRIMARY KEY (`id_cuota`),
  ADD KEY `id_disciplina` (`id_disciplina`),
  ADD KEY `id_credito` (`id_credito`);

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
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id_rol`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD KEY `id_rol` (`id_rol`),
  ADD KEY `fk_usuarios_estado` (`id_estado`);

--
-- Indices de la tabla `usuarios_cuotas`
--
ALTER TABLE `usuarios_cuotas`
  ADD PRIMARY KEY (`id_usuario`,`id_cuota`),
  ADD KEY `id_cuota` (`id_cuota`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `clases`
--
ALTER TABLE `clases`
  MODIFY `id_clase` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `creditos`
--
ALTER TABLE `creditos`
  MODIFY `id_credito` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `cuotas`
--
ALTER TABLE `cuotas`
  MODIFY `id_cuota` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `dias`
--
ALTER TABLE `dias`
  MODIFY `id_dia` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `disciplinas`
--
ALTER TABLE `disciplinas`
  MODIFY `id_disciplina` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `estados`
--
ALTER TABLE `estados`
  MODIFY `id_estado` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `id_rol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

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
  ADD CONSTRAINT `cuotas_ibfk_1` FOREIGN KEY (`id_disciplina`) REFERENCES `disciplinas` (`id_disciplina`),
  ADD CONSTRAINT `cuotas_ibfk_2` FOREIGN KEY (`id_credito`) REFERENCES `creditos` (`id_credito`);

--
-- Filtros para la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD CONSTRAINT `datos_personales_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `fk_usuarios_estado` FOREIGN KEY (`id_estado`) REFERENCES `estados` (`id_estado`),
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`);

--
-- Filtros para la tabla `usuarios_cuotas`
--
ALTER TABLE `usuarios_cuotas`
  ADD CONSTRAINT `usuarios_cuotas_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `usuarios_cuotas_ibfk_2` FOREIGN KEY (`id_cuota`) REFERENCES `cuotas` (`id_cuota`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
