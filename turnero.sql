-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 24-06-2025 a las 00:27:57
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
CREATE DEFINER=`root`@`localhost` PROCEDURE `BuscarUsuariosPorNombre` (IN `nombre_busqueda` VARCHAR(100))   BEGIN
    SELECT 
        u.id_usuario,
        u.email,
        r.rol,
        u.nombre,
        dp.dni,
        dp.celular,
        p.nombre AS nombre_plan,
        c.fecha_pago,
        c.fecha_vencimiento,
        c.estado_pago,
        c.creditos_total,
        c.creditos_disponibles
    FROM usuarios u
    JOIN roles r ON u.id_rol = r.id_rol
    LEFT JOIN datos_personales dp ON u.id_usuario = dp.id_usuario
    LEFT JOIN (
        SELECT id_usuario, id_plan, fecha_pago, fecha_vencimiento, estado_pago, creditos_total, creditos_disponibles
        FROM cuotas
        WHERE fecha_vencimiento >= CURDATE()
        ORDER BY fecha_pago DESC
    ) c ON u.id_usuario = c.id_usuario
    LEFT JOIN planes p ON c.id_plan = p.id_plan
    WHERE u.nombre LIKE CONCAT('%', nombre_busqueda, '%')
    GROUP BY u.id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CreateClass` (IN `p_id_disciplina` INT, IN `p_id_dia` INT, IN `p_hora` TIME, IN `p_capacidad_max` INT)   BEGIN
    INSERT INTO clases (id_disciplina, id_dia, hora, capacidad_max)
    VALUES (p_id_disciplina, p_id_dia, p_hora, p_capacidad_max);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CreateDiscipline` (IN `p_nombre` VARCHAR(100))   BEGIN
    INSERT INTO disciplinas (disciplina, activa)
    VALUES (p_nombre, TRUE);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CreateExercise` (IN `p_name` VARCHAR(100), IN `p_link` VARCHAR(255))   BEGIN
    INSERT INTO ejercicios (nombre, link, activa)
    VALUES (p_name, p_link, TRUE);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CreatePlan` (IN `p_nombre` VARCHAR(100), IN `p_descripcion` TEXT, IN `p_monto` DECIMAL(10,2), IN `p_creditos_total` INT, IN `p_disciplinas` TEXT)   BEGIN
    DECLARE v_id_plan INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE disciplina_id INT;
    DECLARE cur CURSOR FOR SELECT CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(p_disciplinas, ',', n.n), ',', -1)) AS UNSIGNED) AS id
                           FROM (SELECT a.N + b.N * 10 + 1 AS n
                                 FROM (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                                       UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
                                      (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                                       UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
                                 WHERE a.N + b.N * 10 + 1 <= LENGTH(p_disciplinas) - LENGTH(REPLACE(p_disciplinas, ',', '')) + 1
                               ) n;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Insertar el nuevo plan
    INSERT INTO planes (nombre, descripcion, monto, creditos_total, activa)
    VALUES (p_nombre, p_descripcion, p_monto, p_creditos_total, TRUE);

    SET v_id_plan = LAST_INSERT_ID();

    -- Insertar disciplinas asociadas al plan
    OPEN cur;

    leer_loop: LOOP
        FETCH cur INTO disciplina_id;
        IF done THEN
            LEAVE leer_loop;
        END IF;

        INSERT INTO planes_disciplinas (id_plan, id_disciplina)
        VALUES (v_id_plan, disciplina_id);
    END LOOP;

    CLOSE cur;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CreateRM` (IN `p_id_usuario` INT, IN `p_id_ejercicio` INT, IN `p_peso` DECIMAL(10,2), IN `p_repeticiones` INT, IN `p_notas` TEXT)   BEGIN
  -- Verificar si ya existe este RM específico
  IF EXISTS (
    SELECT 1 FROM ejercicios_usuarios_rm 
    WHERE id_usuario = p_id_usuario 
      AND id_ejercicio = p_id_ejercicio
      AND repeticiones = p_repeticiones
  ) THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Ya existe un RM registrado para este usuario, ejercicio y número de repeticiones';
  END IF;

  -- Insertar el nuevo registro
  INSERT INTO ejercicios_usuarios_rm (
    id_usuario, 
    id_ejercicio, 
    peso, 
    repeticiones, 
    notas
  ) VALUES (
    p_id_usuario,
    p_id_ejercicio,
    p_peso,
    p_repeticiones,
    p_notas
  );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CreateUserRoutineWithExercises` (IN `p_id_usuario` INT, IN `p_nombre_rutina` VARCHAR(100), IN `p_ejercicios` TEXT)   BEGIN
    DECLARE v_id_rutina INT;
    DECLARE done INT DEFAULT FALSE;

    DECLARE v_id_ejercicio INT;
    DECLARE v_dia TINYINT;
    DECLARE v_orden INT;
    DECLARE v_rondas INT;
    DECLARE v_repeticiones VARCHAR(50);

    DECLARE cur CURSOR FOR
        SELECT 
            CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 1), ',', -1) AS UNSIGNED),
            CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 2), ',', -1) AS UNSIGNED),
            CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 3), ',', -1) AS UNSIGNED),
            CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 4), ',', -1) AS UNSIGNED),
            SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 5), ',', -1)
        FROM (
            SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(p_ejercicios, ';', numbers.n), ';', -1)) AS e
            FROM (
                SELECT a.N + b.N * 10 + 1 AS n
                FROM (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
                     (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
                WHERE a.N + b.N * 10 + 1 <= LENGTH(p_ejercicios) - LENGTH(REPLACE(p_ejercicios, ';', '')) + 1
            ) numbers
        ) parsed;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Crear la rutina
    INSERT INTO rutina (id_usuario, nombre, activa)
    VALUES (p_id_usuario, p_nombre_rutina, TRUE);

    SET v_id_rutina = LAST_INSERT_ID();

    -- Insertar ejercicios
    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_id_ejercicio, v_dia, v_orden, v_rondas, v_repeticiones;
        IF done THEN
            LEAVE read_loop;
        END IF;

        INSERT INTO rutina_ejercicios (
            id_rutina, id_ejercicio, dia, orden, rondas, repeticiones
        ) VALUES (
            v_id_rutina, v_id_ejercicio, v_dia, v_orden, v_rondas, v_repeticiones
        );
    END LOOP;

    CLOSE cur;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `DeleteClass` (IN `p_id_clase` INT)   BEGIN
    UPDATE clases
    SET activa = FALSE
    WHERE id_clase = p_id_clase;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `DeleteDisciplina` (IN `p_id_disciplina` INT)   BEGIN
    UPDATE disciplinas
    SET activa = FALSE
    WHERE id_disciplina = p_id_disciplina;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `DeleteExercise` (IN `p_id_ejercicio` INT)   BEGIN
  UPDATE ejercicios
  SET activa = FALSE
  WHERE id_ejercicio = p_id_ejercicio;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `DeletePlan` (IN `p_id_plan` INT)   BEGIN
    -- Eliminar relaciones en planes_disciplinas
    DELETE FROM planes_disciplinas
    WHERE id_plan = p_id_plan;

    -- Desactivar el plan
    UPDATE planes
    SET activa = FALSE
    WHERE id_plan = p_id_plan;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `DeleteUserRoutine` (IN `p_id_rutina` INT)   BEGIN
  UPDATE rutina
  SET activa = FALSE
  WHERE id_rutina = p_id_rutina;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetAllClasses` (IN `p_fecha` DATE)   BEGIN
    DECLARE v_dia_semana INT;

    SET v_dia_semana = WEEKDAY(p_fecha) + 1;

    SELECT
        d.disciplina AS disciplina,
        di.dia AS dia,
        c.hora,
        c.id_clase,
        (c.capacidad_max - IFNULL(COUNT(cu.id_usuario), 0)) AS disponibles
    FROM clases c
    JOIN disciplinas d ON c.id_disciplina = d.id_disciplina
    JOIN dias di ON c.id_dia = di.id_dia
    LEFT JOIN clases_usuarios cu 
        ON cu.id_clase = c.id_clase AND cu.fecha = p_fecha
    WHERE c.id_dia = v_dia_semana
    	AND c.activa = TRUE
        AND d.activa = TRUE
    GROUP BY 
        c.id_clase, c.id_disciplina, d.disciplina, 
        c.id_dia, di.dia, c.hora, c.capacidad_max;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetAllExercises` ()   BEGIN
    SELECT id_ejercicio, nombre, link
    FROM ejercicios
    WHERE activa = TRUE;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetClassesByDay` (IN `p_id_dia` INT)   BEGIN
    SELECT 
        c.id_clase,
        c.id_disciplina,
        d.disciplina,
        c.hora,
        c.capacidad_max
    FROM clases c
    JOIN disciplinas d ON c.id_disciplina = d.id_disciplina
    WHERE c.id_dia = p_id_dia
    AND c.activa = TRUE
    AND d.activa = TRUE
    ORDER BY c.hora;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetClassesByUser` (IN `p_id_usuario` INT, IN `p_fecha` DATE)   BEGIN
    DECLARE v_id_plan INT;
    DECLARE v_id_cuota INT;
    DECLARE v_creditos INT;
    DECLARE v_dia_semana INT;

    -- Obtener el día de la semana (lunes=1, domingo=7)
    SET v_dia_semana = WEEKDAY(p_fecha) + 1;

    -- Obtener la última cuota válida (paga, con créditos y vigente para la fecha)
    SELECT id_cuota, id_plan, creditos_disponibles
    INTO v_id_cuota, v_id_plan, v_creditos
    FROM cuotas
    WHERE id_usuario = p_id_usuario
      AND estado_pago = 'Paga'
      AND creditos_disponibles > 0
      AND fecha_vencimiento >= p_fecha
    ORDER BY fecha_pago DESC
    LIMIT 1;

    -- Validar que haya cuota válida
    IF v_id_cuota IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay cuotas válidas con créditos para la fecha indicada.';
    END IF;

    -- Seleccionar clases según el plan y filtrando por día de la semana
    SELECT 
        c.hora,
        c.id_clase,
        (c.capacidad_max - IFNULL(COUNT(cu.id_usuario), 0)) AS disponibles,
        d.dia AS dia,
        dis.disciplina AS disciplina
    FROM clases c
    JOIN planes_disciplinas pd ON c.id_disciplina = pd.id_disciplina
    JOIN disciplinas dis ON c.id_disciplina = dis.id_disciplina
    JOIN dias d ON c.id_dia = d.id_dia
    LEFT JOIN clases_usuarios cu ON cu.id_clase = c.id_clase AND cu.fecha = p_fecha
    WHERE pd.id_plan = v_id_plan
      AND c.id_dia = v_dia_semana
      AND c.activa = TRUE
      AND dis.activa = TRUE
    GROUP BY 
        c.id_clase, c.hora, c.capacidad_max, c.id_dia, d.dia, c.id_disciplina, dis.disciplina;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetDisciplinas` ()   BEGIN
    SELECT id_disciplina, disciplina
    FROM disciplinas
    WHERE activa = TRUE;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetInfoCuotas` (IN `n_id_usuario` INT)   BEGIN
    SELECT
      cuotas.id_usuario,
      SUM(cuotas.creditos_disponibles) AS creditos_disponibles_totales
    FROM cuotas
    WHERE cuotas.id_usuario = n_id_usuario
    GROUP BY cuotas.id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetPlanes` ()   BEGIN
    SELECT id_plan, nombre, descripcion, monto, creditos_total
    FROM planes
    WHERE activa = TRUE;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetRMsUsuario` (IN `p_id_usuario` INT)   BEGIN
  SELECT 
    rm.id_ejercicio,
    e.nombre AS ejercicio,
    rm.peso,
    rm.repeticiones,
    rm.fecha_actualizacion,
    rm.notas
  FROM ejercicios_usuarios_rm rm
  JOIN ejercicios e ON rm.id_ejercicio = e.id_ejercicio
  WHERE rm.id_usuario = p_id_usuario
    AND e.activa = TRUE
  ORDER BY e.nombre;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetRoutinesByUser` (IN `p_id_usuario` INT)   BEGIN
  SELECT 
    r.id_rutina,
    r.nombre AS rutina_nombre,
    re.dia,
    re.orden,
    re.rondas,
    re.repeticiones,
    e.id_ejercicio,
    e.nombre AS ejercicio_nombre,
    e.link
  FROM rutina r
  JOIN rutina_ejercicios re ON r.id_rutina = re.id_rutina
  JOIN ejercicios e ON re.id_ejercicio = e.id_ejercicio
  WHERE r.id_usuario = p_id_usuario
    AND r.activa = TRUE
    AND e.activa = TRUE
  ORDER BY r.id_rutina, re.dia, re.orden;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetRoutinesByUserName` (IN `p_nombre_usuario` VARCHAR(100))   BEGIN
  SELECT 
    r.id_rutina,
    r.nombre AS rutina_nombre,
    u.nombre AS usuario,
    re.dia,
    re.orden,
    re.rondas,
    re.repeticiones,
    e.id_ejercicio,
    e.nombre AS ejercicio_nombre,
    e.link
  FROM rutina r
  JOIN usuarios u ON r.id_usuario = u.id_usuario
  JOIN rutina_ejercicios re ON r.id_rutina = re.id_rutina
  JOIN ejercicios e ON re.id_ejercicio = e.id_ejercicio
  WHERE u.nombre LIKE CONCAT('%', p_nombre_usuario, '%')
    AND r.activa = TRUE
    AND e.activa = TRUE
  ORDER BY r.id_rutina, re.dia, re.orden;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetUserByEmail` (IN `p_email` VARCHAR(255))   BEGIN
    SELECT * FROM usuarios WHERE email = p_email;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetUserFullInfo` (IN `p_id_usuario` INT)   BEGIN
    SELECT 
        u.id_usuario,
        u.nombre,
        u.email,
        r.rol,
        dp.dni,
        dp.celular,
        p.nombre AS nombre_plan,
        c.fecha_pago,
        c.fecha_vencimiento,
        c.estado_pago,
        c.creditos_total,
        c.creditos_disponibles
    FROM usuarios u
    JOIN roles r ON u.id_rol = r.id_rol
    LEFT JOIN datos_personales dp ON u.id_usuario = dp.id_usuario
    LEFT JOIN (
        SELECT *
        FROM cuotas
        WHERE id_usuario = p_id_usuario
          AND fecha_vencimiento >= CURDATE()
        ORDER BY fecha_pago DESC
        LIMIT 1
    ) c ON u.id_usuario = c.id_usuario
    LEFT JOIN planes p ON c.id_plan = p.id_plan
    WHERE u.id_usuario = p_id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetUsersByClassAndDate` (IN `p_class_id` INT, IN `p_date` DATE)   BEGIN
    SELECT u.id_usuario,
    u.nombre
    FROM clases_usuarios cu
    JOIN usuarios u ON cu.id_usuario = u.id_usuario
    WHERE cu.id_clase = p_class_id
      AND cu.fecha = p_date;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterClient` (IN `p_email` VARCHAR(255), IN `p_password` VARCHAR(255), IN `p_nombre` VARCHAR(255), IN `p_dni` VARCHAR(20), IN `p_celular` VARCHAR(10))   BEGIN
    DECLARE new_user_id INT;


    INSERT INTO usuarios (email, password, nombre, id_rol, id_estado)
    VALUES (p_email, p_password, p_nombre, 3, 2);

    SET new_user_id = LAST_INSERT_ID();


    INSERT INTO datos_personales (id_usuario, dni, celular)
    VALUES (new_user_id, p_dni, p_celular);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterToClass` (IN `p_id_usuario` INT, IN `p_id_clase` INT, IN `p_fecha` DATE)   BEGIN
    DECLARE v_creditos INT;
    DECLARE v_estado_usuario INT;
    DECLARE v_id_cuota INT;
    DECLARE v_capacidad_max INT;
    DECLARE v_anotados INT;

    -- Verificar si el usuario está activo
    SELECT id_estado INTO v_estado_usuario
    FROM usuarios
    WHERE id_usuario = p_id_usuario;

    IF v_estado_usuario != 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario no está activo.';
    END IF;

    -- Obtener cuota más reciente con créditos y dentro de la fecha de validez
    SELECT id_cuota, creditos_disponibles INTO v_id_cuota, v_creditos
    FROM cuotas
    WHERE id_usuario = p_id_usuario
      AND creditos_disponibles > 0
      AND fecha_vencimiento >= p_fecha
    ORDER BY fecha_pago DESC
    LIMIT 1;

    -- Verificar si se encontró una cuota válida
    IF v_id_cuota IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay créditos válidos disponibles para esa fecha.';
    END IF;

    -- Verificar capacidad
    SELECT capacidad_max INTO v_capacidad_max
    FROM clases
    WHERE id_clase = p_id_clase;

    SELECT COUNT(*) INTO v_anotados
    FROM clases_usuarios
    WHERE id_clase = p_id_clase AND fecha = p_fecha;

    IF v_anotados >= v_capacidad_max THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay cupos disponibles en esta clase en la fecha seleccionada.';
    END IF;

    -- Insertar en la tabla intermedia con fecha
    INSERT INTO clases_usuarios (id_clase, id_usuario, fecha)
    VALUES (p_id_clase, p_id_usuario, p_fecha);

    -- Descontar crédito en cuota
    UPDATE cuotas
    SET creditos_disponibles = creditos_disponibles - 1
    WHERE id_cuota = v_id_cuota;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterUser` (IN `p_email` VARCHAR(255), IN `p_password` VARCHAR(255), IN `p_nombre` VARCHAR(100), IN `p_dni` VARCHAR(20), IN `p_celular` VARCHAR(20), IN `p_id_rol` INT)   BEGIN
    DECLARE new_user_id INT;

    INSERT INTO usuarios (email, password, nombre, id_rol, id_estado)
    VALUES (p_email, p_password, p_nombre, p_id_rol, 1);

    SET new_user_id = LAST_INSERT_ID();

    INSERT INTO datos_personales (id_usuario, dni, celular)
    VALUES (new_user_id, p_dni, p_celular);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegistrarCuotaPorNombre` (IN `p_nombre_usuario` VARCHAR(100), IN `p_id_plan` INT, IN `p_fecha_pago` DATE)   BEGIN
    DECLARE v_id_usuario INT;
    DECLARE v_creditos_total INT DEFAULT 8;
    DECLARE v_fecha_vencimiento DATE;

    -- Busca el id_usuario por nombre exacto
    SELECT id_usuario INTO v_id_usuario
    FROM usuarios
    WHERE nombre = p_nombre_usuario
    LIMIT 1;

    SET v_fecha_vencimiento = DATE_ADD(p_fecha_pago, INTERVAL 1 MONTH);

    INSERT INTO cuotas (
        id_usuario,
        id_plan,
        fecha_pago,
        fecha_vencimiento,
        estado_pago,
        creditos_total,
        creditos_disponibles
    ) VALUES (
        v_id_usuario,
        p_id_plan,
        p_fecha_pago,
        v_fecha_vencimiento,
        'Paga',
        v_creditos_total,
        v_creditos_total
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SearchExercisesByName` (IN `p_name` VARCHAR(100))   BEGIN
    SELECT id_ejercicio, nombre, link
    FROM ejercicios
    WHERE activa = TRUE AND nombre LIKE CONCAT('%', p_name, '%');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UnregisterFromClass` (IN `p_id_usuario` INT, IN `p_id_clase` INT, IN `p_fecha` DATE)   BEGIN
    DECLARE v_id_cuota INT;
    DECLARE v_estado_usuario INT;

    -- Verificar si el usuario está activo
    SELECT id_estado INTO v_estado_usuario
    FROM usuarios
    WHERE id_usuario = p_id_usuario;

    IF v_estado_usuario != 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario no está activo.';
    END IF;

    -- Verificar si está anotado en esa clase en esa fecha
    IF NOT EXISTS (
        SELECT 1 FROM clases_usuarios
        WHERE id_usuario = p_id_usuario
          AND id_clase = p_id_clase
          AND fecha = p_fecha
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario no está anotado en esta clase para la fecha indicada.';
    END IF;

    -- Obtener cuota válida usada
    SELECT id_cuota INTO v_id_cuota
    FROM cuotas
    WHERE id_usuario = p_id_usuario
      AND fecha_vencimiento >= p_fecha
    ORDER BY fecha_pago DESC
    LIMIT 1;

    IF v_id_cuota IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se encontró una cuota válida para la fecha indicada.';
    END IF;

    -- Eliminar la inscripción
    DELETE FROM clases_usuarios
    WHERE id_usuario = p_id_usuario
      AND id_clase = p_id_clase
      AND fecha = p_fecha;

    -- Sumar 1 crédito a la cuota usada
    UPDATE cuotas
    SET creditos_disponibles = creditos_disponibles + 1
    WHERE id_cuota = v_id_cuota;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdateClasses` (IN `p_id_clase` INT, IN `p_id_disciplina` INT, IN `p_id_dia` INT, IN `p_hora` TIME, IN `p_capacidad_max` INT)   BEGIN
    UPDATE clases
    SET 
        id_disciplina = COALESCE(p_id_disciplina, id_disciplina),
        id_dia = COALESCE(p_id_dia, id_dia),
        hora = COALESCE(p_hora, hora),
        capacidad_max = COALESCE(p_capacidad_max, capacidad_max)
    WHERE id_clase = p_id_clase;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdateExercise` (IN `p_id_ejercicio` INT, IN `p_nombre` VARCHAR(100), IN `p_link` VARCHAR(255))   BEGIN
  UPDATE ejercicios
  SET
    nombre = COALESCE(p_nombre, nombre),
    link = COALESCE(p_link, link)
  WHERE id_ejercicio = p_id_ejercicio;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdatePassword` (IN `p_id_usuario` INT, IN `p_password_hash` VARCHAR(255))   BEGIN
  UPDATE usuarios
  SET password = p_password_hash
  WHERE id_usuario = p_id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdatePlan` (IN `p_id_plan` INT, IN `p_nombre` VARCHAR(100), IN `p_descripcion` TEXT, IN `p_monto` DECIMAL(10,2), IN `p_creditos_total` INT)   BEGIN
    UPDATE planes
    SET 
        nombre = COALESCE(p_nombre, nombre),
        descripcion = COALESCE(p_descripcion, descripcion),
        monto = COALESCE(p_monto, monto),
        creditos_total = COALESCE(p_creditos_total, creditos_total)
    WHERE id_plan = p_id_plan;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdateRM` (IN `p_id_usuario` INT, IN `p_id_ejercicio` INT, IN `p_repeticiones` INT, IN `p_nuevo_peso` DECIMAL(10,2), IN `p_nuevas_notas` TEXT)   BEGIN
  -- Verificar si existe el registro
  IF NOT EXISTS (
    SELECT 1 FROM ejercicios_usuarios_rm 
    WHERE id_usuario = p_id_usuario 
      AND id_ejercicio = p_id_ejercicio
      AND repeticiones = p_repeticiones
  ) THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'No existe un RM registrado para esta combinación de usuario, ejercicio y repeticiones';
  END IF;

  -- Actualizar el registro existente
  UPDATE ejercicios_usuarios_rm
  SET 
    peso = COALESCE(p_nuevo_peso, peso),
    notas = COALESCE(p_nuevas_notas, notas),
    fecha_actualizacion = CURRENT_TIMESTAMP
  WHERE id_usuario = p_id_usuario
    AND id_ejercicio = p_id_ejercicio
    AND repeticiones = p_repeticiones;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdateUserInfo` (IN `p_id_usuario` INT, IN `p_nombre` VARCHAR(100), IN `p_email` VARCHAR(100), IN `p_dni` VARCHAR(20), IN `p_celular` VARCHAR(20))   BEGIN
    UPDATE usuarios
    SET 
        nombre = COALESCE(p_nombre, nombre),
        email = COALESCE(p_email, email)
    WHERE id_usuario = p_id_usuario;

    UPDATE datos_personales
    SET 
        dni = COALESCE(p_dni, dni),
        celular = COALESCE(p_celular, celular)
    WHERE id_usuario = p_id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdateUserRoutine` (IN `p_id_rutina` INT, IN `p_nombre_rutina` VARCHAR(100), IN `p_ejercicios` TEXT)   BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE v_id_ejercicio INT;
  DECLARE v_dia TINYINT;
  DECLARE v_orden INT;
  DECLARE v_rondas INT;
  DECLARE v_repeticiones VARCHAR(50);

  DECLARE cur CURSOR FOR
    SELECT 
      CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 1), ',', -1) AS UNSIGNED),
      CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 2), ',', -1) AS UNSIGNED),
      CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 3), ',', -1) AS UNSIGNED),
      CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 4), ',', -1) AS UNSIGNED),
      SUBSTRING_INDEX(SUBSTRING_INDEX(e, ',', 5), ',', -1)
    FROM (
      SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(p_ejercicios, ';', numbers.n), ';', -1)) AS e
      FROM (
        SELECT a.N + b.N * 10 + 1 AS n
        FROM (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
              UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
             (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
              UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
        WHERE a.N + b.N * 10 + 1 <= LENGTH(p_ejercicios) - LENGTH(REPLACE(p_ejercicios, ';', '')) + 1
      ) numbers
    ) parsed;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  -- Solo actualiza el nombre si se envía un valor no nulo
  IF p_nombre_rutina IS NOT NULL THEN
    UPDATE rutina
    SET nombre = p_nombre_rutina
    WHERE id_rutina = p_id_rutina;
  END IF;

  -- Si se envían ejercicios, reemplazar los existentes
  IF p_ejercicios IS NOT NULL AND p_ejercicios != '' THEN
    DELETE FROM rutina_ejercicios WHERE id_rutina = p_id_rutina;

    OPEN cur;
    read_loop: LOOP
      FETCH cur INTO v_id_ejercicio, v_dia, v_orden, v_rondas, v_repeticiones;
      IF done THEN
        LEAVE read_loop;
      END IF;

      INSERT INTO rutina_ejercicios (
        id_rutina, id_ejercicio, dia, orden, rondas, repeticiones
      ) VALUES (
        p_id_rutina, v_id_ejercicio, v_dia, v_orden, v_rondas, v_repeticiones
      );
    END LOOP;
    CLOSE cur;
  END IF;
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
  `activa` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `clases`
--

INSERT INTO `clases` (`id_clase`, `id_disciplina`, `id_dia`, `hora`, `capacidad_max`, `activa`) VALUES
(1, 1, 1, '18:00:00', 20, 1),
(2, 1, 2, '08:00:00', 20, 1),
(3, 1, 3, '08:00:00', 20, 1),
(4, 1, 4, '08:00:00', 20, 1),
(5, 1, 5, '08:00:00', 20, 1),
(6, 1, 6, '08:00:00', 20, 1),
(7, 2, 1, '09:00:00', 20, 1),
(8, 2, 2, '09:00:00', 20, 1),
(9, 2, 3, '09:00:00', 20, 1),
(10, 2, 4, '09:00:00', 20, 1),
(11, 2, 5, '09:00:00', 20, 1),
(12, 2, 6, '09:00:00', 20, 1),
(13, 3, 1, '10:00:00', 20, 1),
(14, 3, 2, '10:00:00', 20, 1),
(15, 3, 3, '10:00:00', 20, 1),
(16, 3, 4, '10:00:00', 20, 1),
(17, 3, 5, '10:00:00', 20, 1),
(18, 3, 6, '10:00:00', 20, 1),
(19, 4, 1, '11:00:00', 20, 1),
(20, 4, 2, '11:00:00', 20, 1),
(21, 4, 3, '11:00:00', 20, 1),
(22, 4, 4, '11:00:00', 20, 1),
(23, 4, 5, '11:00:00', 20, 1),
(24, 4, 6, '11:00:00', 20, 1),
(25, 5, 1, '12:00:00', 20, 1),
(26, 5, 2, '12:00:00', 20, 1),
(27, 5, 3, '12:00:00', 20, 1),
(28, 5, 4, '12:00:00', 20, 1),
(29, 5, 5, '12:00:00', 20, 1),
(30, 5, 6, '12:00:00', 20, 1),
(31, 5, 1, '13:00:00', 10, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clases_usuarios`
--

CREATE TABLE `clases_usuarios` (
  `id_clase` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `presente` tinyint(1) DEFAULT NULL,
  `fecha` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `clases_usuarios`
--

INSERT INTO `clases_usuarios` (`id_clase`, `id_usuario`, `presente`, `fecha`) VALUES
(1, 4, NULL, '2025-05-26'),
(2, 4, NULL, '2025-05-27'),
(7, 4, NULL, '2025-05-26'),
(10, 4, NULL, '2025-06-05');

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
(1, 4, 1, '2025-05-12', '2025-06-11', 'Paga', 8, 28);

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
(7, '41717495', '1199999999'),
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
  `disciplina` varchar(100) DEFAULT NULL,
  `activa` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `disciplinas`
--

INSERT INTO `disciplinas` (`id_disciplina`, `disciplina`, `activa`) VALUES
(1, 'Crossfit', 1),
(2, 'Funcional', 1),
(3, 'Musculación', 1),
(4, 'Open box', 1),
(5, 'Levantamiento olímpico', 1),
(6, 'Pilates', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ejercicios`
--

CREATE TABLE `ejercicios` (
  `id_ejercicio` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `link` varchar(255) DEFAULT NULL,
  `activa` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `ejercicios`
--

INSERT INTO `ejercicios` (`id_ejercicio`, `nombre`, `link`, `activa`) VALUES
(1, 'Sentadilla', '', 1),
(2, 'Peso Rumano con Dumbbell', 'https://www.youtube.com/watch?v=xAL7lHwj30E', 1),
(3, 'Hip Thrust', 'https://www.youtube.com/watch?v=RkgpqqpHHlE', 1),
(4, 'Peso Rumano con Barra', 'https://youtu.be/aJbKyX6MDgM?si=ObshFeiRlPKAQ_36', 1),
(5, 'Sentadilla Sumo', 'https://youtu.be/UkM1ZjH2HWA?si=AInMeuQzLEf9hHws', 1),
(6, 'Extensiones de Cuadriceps', 'https://youtu.be/GEqOeRYV3Qs?si=-rKclBXUHhdrYuzd', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ejercicios_usuarios_rm`
--

CREATE TABLE `ejercicios_usuarios_rm` (
  `id_usuario` int(11) NOT NULL,
  `id_ejercicio` int(11) NOT NULL,
  `peso` decimal(10,2) DEFAULT NULL COMMENT 'Peso máximo en kg',
  `repeticiones` int(11) NOT NULL,
  `fecha_actualizacion` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `notas` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `ejercicios_usuarios_rm`
--

INSERT INTO `ejercicios_usuarios_rm` (`id_usuario`, `id_ejercicio`, `peso`, `repeticiones`, `fecha_actualizacion`, `notas`) VALUES
(4, 1, 85.00, 1, '2025-06-23 22:26:10', '');

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
  `creditos_total` int(11) NOT NULL,
  `activa` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `planes`
--

INSERT INTO `planes` (`id_plan`, `nombre`, `descripcion`, `monto`, `creditos_total`, `activa`) VALUES
(1, 'Plan 8c multidisciplina', 'Permite asistir dos veces por semana a dos disciplinas', 20000.00, 8, 1),
(3, 'Crossfit Semanal', '6 creditos semanales para Crossfit', 26000.00, 24, 1),
(4, 'Plan Full', 'Acceso a todas las disciplinas', 25000.00, 24, 0);

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
-- Estructura de tabla para la tabla `rutina`
--

CREATE TABLE `rutina` (
  `id_rutina` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `activa` tinyint(1) DEFAULT 1,
  `nombre` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `rutina`
--

INSERT INTO `rutina` (`id_rutina`, `id_usuario`, `activa`, `nombre`) VALUES
(2, 4, 1, 'Piernas');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `rutina_ejercicios`
--

CREATE TABLE `rutina_ejercicios` (
  `id_rutina` int(11) NOT NULL,
  `id_ejercicio` int(11) NOT NULL,
  `dia` tinyint(4) NOT NULL,
  `orden` int(11) DEFAULT 1,
  `rondas` int(11) DEFAULT 1,
  `repeticiones` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `rutina_ejercicios`
--

INSERT INTO `rutina_ejercicios` (`id_rutina`, `id_ejercicio`, `dia`, `orden`, `rondas`, `repeticiones`) VALUES
(2, 3, 2, 1, 4, '10'),
(2, 5, 2, 2, 3, '12');

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
(4, 'lau@example.com', '$2b$10$JNw8UvDnif80vSmv1aCdqe0CJzLq.dZ5DyFagSAWUE2UGvPg6u9RS', 3, 'Lautaro Bustamante', 1),
(6, 'solsv7@gmail.com', '$2b$10$JucDwzLHnEQzABUNumPYf.IgNDbtqD9WfPm.K1l2A8ve5j8d35bny', 2, 'Sol', 1),
(7, 'ivomonti1@gmail.com', '$2b$10$JY0E6Fs3l/t8YNp0LRU9n.urFfsF8RFYial53cg/BMTgNmAS565Du', 1, 'Ivo', 1),
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
  ADD PRIMARY KEY (`id_clase`,`id_usuario`,`fecha`),
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
-- Indices de la tabla `ejercicios`
--
ALTER TABLE `ejercicios`
  ADD PRIMARY KEY (`id_ejercicio`);

--
-- Indices de la tabla `ejercicios_usuarios_rm`
--
ALTER TABLE `ejercicios_usuarios_rm`
  ADD PRIMARY KEY (`id_usuario`,`id_ejercicio`,`repeticiones`),
  ADD KEY `id_ejercicio` (`id_ejercicio`);

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
-- Indices de la tabla `rutina`
--
ALTER TABLE `rutina`
  ADD PRIMARY KEY (`id_rutina`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `rutina_ejercicios`
--
ALTER TABLE `rutina_ejercicios`
  ADD PRIMARY KEY (`id_rutina`,`id_ejercicio`,`dia`),
  ADD KEY `id_ejercicio` (`id_ejercicio`);

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
  MODIFY `id_clase` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=32;

--
-- AUTO_INCREMENT de la tabla `cuotas`
--
ALTER TABLE `cuotas`
  MODIFY `id_cuota` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `dias`
--
ALTER TABLE `dias`
  MODIFY `id_dia` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `disciplinas`
--
ALTER TABLE `disciplinas`
  MODIFY `id_disciplina` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `ejercicios`
--
ALTER TABLE `ejercicios`
  MODIFY `id_ejercicio` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `estados`
--
ALTER TABLE `estados`
  MODIFY `id_estado` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `planes`
--
ALTER TABLE `planes`
  MODIFY `id_plan` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `id_rol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `rutina`
--
ALTER TABLE `rutina`
  MODIFY `id_rutina` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

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
-- Filtros para la tabla `ejercicios_usuarios_rm`
--
ALTER TABLE `ejercicios_usuarios_rm`
  ADD CONSTRAINT `ejercicios_usuarios_rm_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `ejercicios_usuarios_rm_ibfk_2` FOREIGN KEY (`id_ejercicio`) REFERENCES `ejercicios` (`id_ejercicio`);

--
-- Filtros para la tabla `planes_disciplinas`
--
ALTER TABLE `planes_disciplinas`
  ADD CONSTRAINT `planes_disciplinas_ibfk_1` FOREIGN KEY (`id_plan`) REFERENCES `planes` (`id_plan`),
  ADD CONSTRAINT `planes_disciplinas_ibfk_2` FOREIGN KEY (`id_disciplina`) REFERENCES `disciplinas` (`id_disciplina`);

--
-- Filtros para la tabla `rutina`
--
ALTER TABLE `rutina`
  ADD CONSTRAINT `rutina_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Filtros para la tabla `rutina_ejercicios`
--
ALTER TABLE `rutina_ejercicios`
  ADD CONSTRAINT `rutina_ejercicios_ibfk_1` FOREIGN KEY (`id_rutina`) REFERENCES `rutina` (`id_rutina`) ON DELETE CASCADE,
  ADD CONSTRAINT `rutina_ejercicios_ibfk_2` FOREIGN KEY (`id_ejercicio`) REFERENCES `ejercicios` (`id_ejercicio`) ON DELETE CASCADE;

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
