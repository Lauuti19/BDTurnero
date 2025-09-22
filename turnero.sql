-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: db
-- Generation Time: Sep 22, 2025 at 10:31 PM
-- Server version: 9.4.0
-- PHP Version: 8.2.27

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `turnero`
--

DELIMITER $$
--
-- Procedures
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

CREATE DEFINER=`root`@`%` PROCEDURE `CreateHorasPactadas` (IN `p_id_usuario` INT, IN `p_horas_pactadas` INT, IN `p_tarifa` DECIMAL(10,2))   BEGIN
    -- Validar que no tenga ya un registro
    IF EXISTS (SELECT 1 FROM horas_pactadas WHERE id_usuario = p_id_usuario) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario ya tiene horas pactadas asignadas';
    END IF;

    INSERT INTO horas_pactadas (id_usuario, horas_pactadas, tarifa)
    VALUES (p_id_usuario, p_horas_pactadas, p_tarifa);
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

CREATE DEFINER=`root`@`%` PROCEDURE `CreateProduct` (IN `p_nombre` VARCHAR(100), IN `p_descripcion` TEXT, IN `p_precio` DECIMAL(10,2), IN `p_stock` INT)   BEGIN
    INSERT INTO productos (nombre, descripcion, precio, stock)
    VALUES (p_nombre, p_descripcion, p_precio, p_stock);
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

CREATE DEFINER=`root`@`%` PROCEDURE `CreateWorkHours` (IN `p_user_id` INT, IN `p_work_hours` INT, IN `p_rate` DECIMAL(10,2))   BEGIN
    -- If a previous inactive record exists, reactivate it instead of inserting duplicate
    IF EXISTS (SELECT 1 FROM horas_pactadas WHERE id_usuario = p_user_id AND active = 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The user already has active assigned work hours';
    END IF;

    INSERT INTO horas_pactadas (id_usuario, horas_pactadas, tarifa, active)
    VALUES (p_user_id, p_work_hours, p_rate, 1);
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

CREATE DEFINER=`root`@`%` PROCEDURE `DeleteProduct` (IN `p_id_producto` INT)   BEGIN
    DELETE FROM productos
    WHERE id_producto = p_id_producto;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `DeleteUserRoutine` (IN `p_id_rutina` INT)   BEGIN
  UPDATE rutina
  SET activa = FALSE
  WHERE id_rutina = p_id_rutina;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetActiveFees` (IN `p_id_usuario` INT, IN `p_current_date` DATE)   BEGIN
    SELECT 
        c.id_cuota,
        c.id_plan,
        c.fecha_pago,
        c.fecha_vencimiento,
        c.estado_pago,
        c.creditos_total,
        c.creditos_disponibles,
        p.nombre AS plan_nombre,
        p.monto   AS plan_monto
    FROM cuotas c
    JOIN planes p ON c.id_plan = p.id_plan
    WHERE c.id_usuario = p_id_usuario
      AND c.fecha_vencimiento >= p_current_date;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetAllCashMovements` ()   BEGIN
    SELECT 
        m.id_movimiento AS movement_id,
        m.fecha AS date,
        m.tipo AS type,
        m.concepto AS concept,
        m.metodo_pago AS payment_method,
        m.monto AS total_amount,
        m.pagado AS paid,
        m.id_usuario AS user_id,
        u.nombre AS user_name,
        m.id_cuota AS fee_id,
        CASE 
            WHEN m.id_cuota IS NOT NULL THEN CONCAT(pl.nombre, ' - $', pl.monto)
            ELSE GROUP_CONCAT(
                    CONCAT(p.nombre, ' (x', d.cantidad, ') - $', d.monto)
                    SEPARATOR '\n'
                 )
        END AS productos
    FROM caja_movimientos m
    LEFT JOIN caja_detalle d ON m.id_movimiento = d.id_movimiento
    LEFT JOIN productos p ON d.id_producto = p.id_producto
    LEFT JOIN usuarios u ON m.id_usuario = u.id_usuario
    LEFT JOIN cuotas c ON m.id_cuota = c.id_cuota
    LEFT JOIN planes pl ON c.id_plan = pl.id_plan
    GROUP BY m.id_movimiento
    ORDER BY m.fecha DESC;
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

CREATE DEFINER=`root`@`%` PROCEDURE `GetAsistenciasProfes` (IN `p_desde` DATE, IN `p_hasta` DATE, IN `p_periodo` CHAR(7))   BEGIN
    SELECT a.id_asistencia, a.id_usuario, u.nombre, a.fecha, a.check_in, a.check_out, a.horas_total
    FROM asistencia_profes a
    JOIN usuarios u ON a.id_usuario = u.id_usuario
    WHERE (p_desde IS NOT NULL AND p_hasta IS NOT NULL AND a.fecha BETWEEN p_desde AND p_hasta)
       OR (p_periodo IS NOT NULL AND DATE_FORMAT(a.fecha, '%Y-%m') = p_periodo)
    ORDER BY a.fecha DESC;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetAttendanceStatus` (IN `p_id_usuario` INT, IN `p_fecha` DATE)   BEGIN
  DECLARE v_check_in TIME;
  DECLARE v_check_out TIME;

  /* Tomo el último registro de ese día para ese usuario */
  SELECT MAX(check_in), MAX(check_out)
    INTO v_check_in, v_check_out
  FROM asistencia_profes
  WHERE id_usuario = p_id_usuario
    AND fecha = p_fecha;

  /* Respondo una sola fila con el estado y las horas (si existen) */
  IF v_check_in IS NULL THEN
    SELECT 'none' AS status, NULL AS check_in, NULL AS check_out;
  ELSEIF v_check_out IS NULL THEN
    SELECT 'in'   AS status, v_check_in AS check_in, NULL AS check_out;
  ELSE
    SELECT 'done' AS status, v_check_in AS check_in, v_check_out AS check_out;
  END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetCashEfectivoDisponible` ()   BEGIN
  SELECT
    COALESCE(
      SUM(
        CASE
          WHEN metodo_pago = 'efectivo' AND tipo = 'ingreso' THEN monto
          WHEN metodo_pago = 'efectivo' AND tipo = 'egreso' THEN -monto
          ELSE 0
        END
      ), 0
    ) AS efectivo_disponible
  FROM caja_movimientos
  WHERE DATE(fecha) = CURDATE();
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetCashMovementsByDateRange` (IN `start_date` DATE, IN `end_date` DATE)   BEGIN
    SELECT 
        m.id_movimiento AS movement_id,
        m.fecha AS date,
        m.tipo AS type,
        m.concepto AS concept,
        m.metodo_pago AS payment_method,
        m.monto AS total_amount,
        m.pagado AS paid,
        m.id_usuario AS user_id,
        u.nombre AS user_name,
        m.id_cuota AS fee_id,
        CASE 
            WHEN m.id_cuota IS NOT NULL THEN CONCAT(pl.nombre, ' - $', pl.monto)
            ELSE GROUP_CONCAT(
                    CONCAT(p.nombre, ' (x', d.cantidad, ') - $', d.monto)
                    SEPARATOR '\n'
                 )
        END AS productos
    FROM caja_movimientos m
    LEFT JOIN caja_detalle d ON m.id_movimiento = d.id_movimiento
    LEFT JOIN productos p ON d.id_producto = p.id_producto
    LEFT JOIN usuarios u ON m.id_usuario = u.id_usuario
    LEFT JOIN cuotas c ON m.id_cuota = c.id_cuota
    LEFT JOIN planes pl ON c.id_plan = pl.id_plan
    WHERE DATE(m.fecha) BETWEEN start_date AND end_date
    GROUP BY m.id_movimiento
    ORDER BY m.fecha DESC;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetCashSummaryByPaymentMethod` ()   BEGIN
  SELECT
    metodo_pago,
    SUM(CASE WHEN tipo = 'ingreso' THEN monto ELSE 0 END) AS total_ingresos,
    SUM(CASE WHEN tipo = 'egreso' THEN monto ELSE 0 END) AS total_egresos,
    SUM(CASE WHEN tipo = 'ingreso' THEN monto ELSE -monto END) AS balance
  FROM caja_movimientos
  GROUP BY metodo_pago;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetCheckStatusDia` (IN `p_id_usuario` INT, IN `p_fecha` DATE)   BEGIN
    DECLARE v_pendientes INT;

    -- ¿Cuántos check-in sin check-out hay ese día?
    SELECT COUNT(*) INTO v_pendientes
    FROM asistencia_profes
    WHERE id_usuario = p_id_usuario
      AND fecha = p_fecha
      AND check_out IS NULL;

    IF v_pendientes > 0 THEN
        -- Hay al menos un check-in abierto sin check-out
        SELECT 'CHECK_OUT' AS accion;
    ELSE
        -- Todos los registros están cerrados → permitir nuevo check-in
        SELECT 'CHECK_IN' AS accion;
    END IF;
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

CREATE DEFINER=`root`@`%` PROCEDURE `GetHorasTrabajadasProfes` (IN `p_desde` DATE, IN `p_hasta` DATE, IN `p_periodo` CHAR(7))   BEGIN
    SELECT u.id_usuario, u.nombre, COALESCE(SUM(a.horas_total),0) AS horas_trabajadas
    FROM usuarios u
    LEFT JOIN asistencia_profes a ON u.id_usuario = a.id_usuario
    WHERE u.id_rol IN (1,2)
      AND (
        (p_desde IS NOT NULL AND p_hasta IS NOT NULL AND a.fecha BETWEEN p_desde AND p_hasta)
        OR (p_periodo IS NOT NULL AND DATE_FORMAT(a.fecha, '%Y-%m') = p_periodo)
      )
    GROUP BY u.id_usuario, u.nombre;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetPlanes` ()   BEGIN
    SELECT id_plan, nombre, descripcion, monto, creditos_total
    FROM planes
    WHERE activa = TRUE;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetPreLiquidacionProfesor` (IN `p_id_usuario` INT, IN `p_periodo` CHAR(7))   BEGIN
    DECLARE v_horas_pactadas INT;
    DECLARE v_tarifa DECIMAL(10,2);
    DECLARE v_horas_trabajadas DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);

    -- Horas pactadas y tarifa
    SELECT horas_pactadas, tarifa
    INTO v_horas_pactadas, v_tarifa
    FROM horas_pactadas
    WHERE id_usuario = p_id_usuario;

    -- Sumar todas las horas trabajadas del mes
    SELECT IFNULL(SUM(horas_total),0)
    INTO v_horas_trabajadas
    FROM asistencia_profes
    WHERE id_usuario = p_id_usuario
      AND DATE_FORMAT(fecha, '%Y-%m') = p_periodo;

    -- Calcular total
    SET v_total = v_horas_trabajadas * v_tarifa;

    -- Devolver resultado sin insertar
    SELECT 
        p_id_usuario AS id_usuario,
        p_periodo   AS periodo,
        v_horas_pactadas AS horas_pactadas,
        v_tarifa    AS tarifa,
        v_horas_trabajadas AS horas_trabajadas,
        v_total     AS total;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetProducts` ()   BEGIN
    SELECT * FROM productos;
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

CREATE DEFINER=`root`@`%` PROCEDURE `GetTodayCashMovements` ()   BEGIN
    SELECT 
        m.id_movimiento AS movement_id,
        m.fecha AS date,
        m.tipo AS type,
        m.concepto AS concept,
        m.metodo_pago AS payment_method,
        m.monto AS total_amount,
        m.pagado AS paid,
        m.id_usuario AS user_id,
        u.nombre AS user_name,
        m.id_cuota AS fee_id,
        -- Si es cuota muestro plan, si no los productos
        CASE 
            WHEN m.id_cuota IS NOT NULL THEN CONCAT(pl.nombre, ' - $', pl.monto)
            ELSE GROUP_CONCAT(
                    CONCAT(p.nombre, ' (x', d.cantidad, ') - $', d.monto)
                    SEPARATOR '\n'
                 )
        END AS productos
    FROM caja_movimientos m
    LEFT JOIN caja_detalle d ON m.id_movimiento = d.id_movimiento
    LEFT JOIN productos p ON d.id_producto = p.id_producto
    LEFT JOIN usuarios u ON m.id_usuario = u.id_usuario
    LEFT JOIN cuotas c ON m.id_cuota = c.id_cuota
    LEFT JOIN planes pl ON c.id_plan = pl.id_plan
    WHERE DATE(m.fecha) = CURDATE()
    GROUP BY m.id_movimiento
    ORDER BY m.fecha DESC;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetTodayCashSummary` ()   BEGIN
  SELECT
    COALESCE(SUM(CASE WHEN tipo='ingreso' THEN monto ELSE 0 END), 0) AS total_ingresos,
    COALESCE(SUM(CASE WHEN tipo='egreso' THEN monto ELSE 0 END), 0) AS total_egresos,
    COALESCE(SUM(CASE WHEN tipo='ingreso' THEN monto ELSE -monto END), 0) AS saldo_dia
  FROM caja_movimientos
  WHERE DATE(fecha) = CURDATE();
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

CREATE DEFINER=`root`@`%` PROCEDURE `GetWorkedHours` (IN `p_id_usuario` INT, IN `p_periodo` CHAR(7))   BEGIN
    -- Si no envías periodo (o viene vacío), uso el mes actual YYYY-MM
    DECLARE v_periodo CHAR(7);
    SET v_periodo = IFNULL(NULLIF(p_periodo, ''), DATE_FORMAT(CURDATE(), '%Y-%m'));

    SELECT COALESCE(SUM(horas_total), 0) AS horas_trabajadas
    FROM asistencia_profes
    WHERE id_usuario = p_id_usuario
      AND DATE_FORMAT(fecha, '%Y-%m') = v_periodo;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetWorkedHoursByRange` (IN `p_id_usuario` INT, IN `p_desde` DATE, IN `p_hasta` DATE)   BEGIN
    SELECT COALESCE(SUM(horas_total), 0) AS horas_trabajadas
    FROM asistencia_profes
    WHERE id_usuario = p_id_usuario
      AND fecha BETWEEN p_desde AND p_hasta;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `GetWorkHours` (IN `p_user_id` INT)   BEGIN
    IF p_user_id IS NULL THEN
        SELECT hp.id_pactado, hp.id_usuario, u.nombre AS user_name,
               hp.horas_pactadas AS work_hours, hp.tarifa AS rate, hp.active
        FROM horas_pactadas hp
        JOIN usuarios u ON hp.id_usuario = u.id_usuario
        WHERE hp.active = 1;
    ELSE
        SELECT hp.id_pactado, hp.id_usuario, u.nombre AS user_name,
               hp.horas_pactadas AS work_hours, hp.tarifa AS rate, hp.active
        FROM horas_pactadas hp
        JOIN usuarios u ON hp.id_usuario = u.id_usuario
        WHERE hp.id_usuario = p_user_id
          AND hp.active = 1;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `LiquidarProfesor` (IN `p_id_usuario` INT, IN `p_periodo` CHAR(7), IN `p_horas_pagadas` DECIMAL(10,2))   BEGIN
    DECLARE v_horas_pactadas INT;
    DECLARE v_tarifa DECIMAL(10,2);
    DECLARE v_horas_trabajadas DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_exists INT;

    -- Validar que no exista ya una liquidación para este usuario y periodo
    SELECT COUNT(*) INTO v_exists
    FROM liquidaciones_profes
    WHERE id_usuario = p_id_usuario
      AND periodo = p_periodo;

    IF v_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ya existe una liquidación para este profesor en el periodo indicado.';
    END IF;

    -- Horas pactadas y tarifa
    SELECT horas_pactadas, tarifa
    INTO v_horas_pactadas, v_tarifa
    FROM horas_pactadas
    WHERE id_usuario = p_id_usuario;

    -- Sumar todas las horas trabajadas del mes
    SELECT IFNULL(SUM(horas_total),0)
    INTO v_horas_trabajadas
    FROM asistencia_profes
    WHERE id_usuario = p_id_usuario
      AND DATE_FORMAT(fecha, '%Y-%m') = p_periodo;

    -- Calcular total en base a las horas que quiero pagar
    SET v_total = p_horas_pagadas * v_tarifa;

    -- Insertar liquidación
    INSERT INTO liquidaciones_profes (
        id_usuario, periodo, horas_pactadas, horas_trabajadas,
        horas_pagadas, total
    ) VALUES (
        p_id_usuario, p_periodo, v_horas_pactadas, v_horas_trabajadas,
        p_horas_pagadas, v_total
    );
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `ObtenerLiquidacionesPorRango` (IN `fecha_inicio` DATE, IN `fecha_fin` DATE)   BEGIN
    SELECT 
        l.id_liquidacion,
        l.id_usuario,
        u.nombre AS profesor,
        l.periodo,
        l.horas_pactadas,
        l.horas_trabajadas,
        l.horas_pagadas,
        l.total
    FROM liquidaciones_profes l
    JOIN usuarios u ON l.id_usuario = u.id_usuario
    WHERE l.fecha_liquidacion BETWEEN fecha_inicio AND fecha_fin
    ORDER BY l.fecha_liquidacion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `PayFee` (IN `p_id_cuota` INT, IN `p_metodo_pago` ENUM('efectivo','transferencia'))   BEGIN
    DECLARE v_id_usuario INT;
    DECLARE v_monto DECIMAL(10,2);
    DECLARE v_exists_mov INT;

    -- 1. Validar que exista la cuota y esté pendiente
    SELECT c.id_usuario, p.monto
    INTO v_id_usuario, v_monto
    FROM cuotas c
    JOIN planes p ON c.id_plan = p.id_plan
    WHERE c.id_cuota = p_id_cuota
      AND c.estado_pago = 'Pendiente'
    LIMIT 1;

    IF v_id_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cuota no existe o ya está paga/vencida';
    END IF;

    -- 2. Marcar la cuota como paga
    UPDATE cuotas
    SET estado_pago = 'Paga',
        fecha_pago = CURDATE()
    WHERE id_cuota = p_id_cuota;

    -- 3. Verificar si ya existe movimiento en caja
    SELECT COUNT(*) INTO v_exists_mov
    FROM caja_movimientos
    WHERE id_cuota = p_id_cuota;

    IF v_exists_mov > 0 THEN
        -- Actualizar movimiento existente
        UPDATE caja_movimientos
        SET pagado = TRUE,
            metodo_pago = p_metodo_pago
        WHERE id_cuota = p_id_cuota;
    ELSE
        -- Insertar nuevo movimiento si falta
        INSERT INTO caja_movimientos (
            tipo, concepto, metodo_pago, monto, pagado, id_usuario, id_cuota
        )
        VALUES ('ingreso', 'cuota', p_metodo_pago, v_monto, TRUE, v_id_usuario, p_id_cuota);
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `RegisterCajaMovimiento` (IN `p_tipo` ENUM('Ingreso','Egreso'), IN `p_metodo_pago` ENUM('Efectivo','Tarjeta','Transferencia'), IN `p_id_usuario` INT, IN `p_concepto` VARCHAR(100), IN `p_detalles` JSON, IN `p_pagado` TINYINT)   BEGIN
    DECLARE v_id_movimiento INT;
    DECLARE v_total DECIMAL(10,2) DEFAULT 0;
    DECLARE v_index INT DEFAULT 0;
    DECLARE v_length INT;
    DECLARE v_id_producto INT;
    DECLARE v_cantidad INT;
    DECLARE v_precio DECIMAL(10,2);

    -- Insertamos cabecera con monto = 0 (se actualiza después)
    INSERT INTO caja_movimientos (fecha, tipo, concepto, metodo_pago, monto, pagado, id_usuario, id_cuota)
    VALUES (NOW(), p_tipo, p_concepto, p_metodo_pago, 0, p_pagado, p_id_usuario, NULL);

    SET v_id_movimiento = LAST_INSERT_ID();

    -- Cantidad de ítems en el JSON
    SET v_length = JSON_LENGTH(p_detalles);

    -- Iteramos sobre los detalles
    WHILE v_index < v_length DO
        SET v_id_producto = JSON_UNQUOTE(JSON_EXTRACT(p_detalles, CONCAT('$[', v_index, '].id_producto')));
        SET v_cantidad    = JSON_UNQUOTE(JSON_EXTRACT(p_detalles, CONCAT('$[', v_index, '].cantidad')));

        -- Buscar precio unitario desde productos
        SELECT precio INTO v_precio
        FROM productos
        WHERE id_producto = v_id_producto;

        -- Insertar detalle
        INSERT INTO caja_detalle (id_movimiento, id_producto, cantidad, precio_unitario)
        VALUES (v_id_movimiento, v_id_producto, v_cantidad, v_precio);

        -- Acumular total
        SET v_total = v_total + (v_precio * v_cantidad);

        SET v_index = v_index + 1;
    END WHILE;

    -- Actualizar monto en cabecera
    UPDATE caja_movimientos
    SET monto = v_total
    WHERE id_movimiento = v_id_movimiento;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `RegisterCashOut` (IN `p_metodo_pago` ENUM('efectivo','transferencia'), IN `p_id_usuario` INT, IN `p_concepto` VARCHAR(100), IN `p_monto` DECIMAL(10,2), IN `p_pagado` TINYINT)   BEGIN
    INSERT INTO caja_movimientos (
        fecha, tipo, concepto, metodo_pago, monto, pagado, id_usuario, id_cuota
    )
    VALUES (
        NOW(), 'egreso', p_concepto, p_metodo_pago, p_monto, p_pagado, p_id_usuario, NULL
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterClient` (IN `p_email` VARCHAR(255), IN `p_password` VARCHAR(255), IN `p_nombre` VARCHAR(255), IN `p_dni` VARCHAR(20), IN `p_celular` VARCHAR(10))   BEGIN
    DECLARE new_user_id INT;


    INSERT INTO usuarios (email, password, nombre, id_rol, id_estado)
    VALUES (p_email, p_password, p_nombre, 3, 2);

    SET new_user_id = LAST_INSERT_ID();


    INSERT INTO datos_personales (id_usuario, dni, celular)
    VALUES (new_user_id, p_dni, p_celular);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RegisterFee` (IN `p_id_usuario` INT, IN `p_id_plan` INT, IN `p_metodo_pago` ENUM('efectivo','transferencia'), IN `p_pagado` BOOLEAN)   BEGIN
    DECLARE v_creditos INT;
    DECLARE v_monto DECIMAL(10,2);
    DECLARE v_id_cuota INT;
    DECLARE v_estado ENUM('Paga','Pendiente','Vencida');

    -- 0. Verificar si ya existe una cuota pendiente/activa
    IF EXISTS (
        SELECT 1
        FROM cuotas
        WHERE id_usuario = p_id_usuario
          AND id_plan = p_id_plan
          AND estado_pago IN ('Pendiente')
          AND fecha_vencimiento >= CURDATE()
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario ya tiene una cuota pendiente para este plan';
    END IF;

    -- 1. Obtener datos del plan
    SELECT creditos_total, monto
    INTO v_creditos, v_monto
    FROM planes
    WHERE id_plan = p_id_plan;

    -- 2. Definir estado de la cuota
    IF p_pagado THEN
        SET v_estado = 'Paga';
    ELSE
        SET v_estado = 'Pendiente';
    END IF;

    -- 3. Insertar cuota
    INSERT INTO cuotas (
        id_usuario, id_plan, fecha_pago, fecha_vencimiento,
        estado_pago, creditos_total, creditos_disponibles
    )
    VALUES (
        p_id_usuario, p_id_plan, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 MONTH),
        v_estado, v_creditos, v_creditos
    );

    SET v_id_cuota = LAST_INSERT_ID();

    -- 4. Registrar movimiento en caja
    INSERT INTO caja_movimientos (tipo, concepto, metodo_pago, monto, pagado, id_usuario, id_cuota)
    VALUES ('ingreso', 'cuota', p_metodo_pago, v_monto, p_pagado, p_id_usuario, v_id_cuota);

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

CREATE DEFINER=`root`@`%` PROCEDURE `RegistrarCheckIn` (IN `p_id_usuario` INT, IN `p_fecha` DATE, IN `p_hora` TIME)   BEGIN
    INSERT INTO asistencia_profes (id_usuario, fecha, check_in)
    VALUES (p_id_usuario, p_fecha, p_hora);
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `RegistrarCheckOut` (IN `p_id_usuario` INT, IN `p_fecha` DATE, IN `p_hora` TIME)   BEGIN
    DECLARE v_id_asistencia INT;
    DECLARE v_check_in TIME;

    SELECT id_asistencia, check_in
    INTO v_id_asistencia, v_check_in
    FROM asistencia_profes
    WHERE id_usuario = p_id_usuario
      AND fecha = p_fecha
      AND check_out IS NULL
    ORDER BY check_in DESC
    LIMIT 1;

    IF v_id_asistencia IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No existe un check-in pendiente para cerrar.';
    END IF;

    UPDATE asistencia_profes
    SET check_out = p_hora,
        horas_total = TIMESTAMPDIFF(MINUTE, v_check_in, p_hora) / 60
    WHERE id_asistencia = v_id_asistencia;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SearchExercisesByName` (IN `p_name` VARCHAR(100))   BEGIN
    SELECT id_ejercicio, nombre, link
    FROM ejercicios
    WHERE activa = TRUE AND nombre LIKE CONCAT('%', p_name, '%');
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SoftDeleteWorkHours` (IN `p_id_pactado` INT)   BEGIN
    UPDATE horas_pactadas
    SET active = 0
    WHERE id_pactado = p_id_pactado;
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

CREATE DEFINER=`root`@`%` PROCEDURE `UpdateProductPrice` (IN `p_id_producto` INT, IN `p_precio` DECIMAL(10,2))   BEGIN
    UPDATE productos
    SET precio = COALESCE(p_precio, precio)
    WHERE id_producto = p_id_producto;
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

CREATE DEFINER=`root`@`%` PROCEDURE `UpdateWorkHours` (IN `p_id_pactado` INT, IN `p_work_hours` INT, IN `p_rate` DECIMAL(10,2))   BEGIN
    UPDATE horas_pactadas
    SET horas_pactadas = COALESCE(p_work_hours, horas_pactadas),
        tarifa = COALESCE(p_rate, tarifa)
    WHERE id_pactado = p_id_pactado
      AND active = 1;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `asistencia_profes`
--

CREATE TABLE `asistencia_profes` (
  `id_asistencia` int NOT NULL,
  `id_usuario` int NOT NULL,
  `fecha` date NOT NULL,
  `check_in` time DEFAULT NULL,
  `check_out` time DEFAULT NULL,
  `horas_total` decimal(5,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `asistencia_profes`
--

INSERT INTO `asistencia_profes` (`id_asistencia`, `id_usuario`, `fecha`, `check_in`, `check_out`, `horas_total`) VALUES
(1, 6, '2025-08-19', '10:00:00', '14:00:00', 4.00),
(2, 6, '2025-08-25', '08:00:00', '12:00:00', 4.00),
(3, 9, '2025-08-25', '13:00:00', '21:00:00', 8.00),
(4, 9, '2025-08-26', '13:00:00', '21:00:00', 8.00),
(5, 6, '2025-09-09', '21:50:45', NULL, NULL),
(6, 6, '2025-09-22', '17:42:05', '17:58:55', 0.27),
(7, 6, '2025-09-22', '17:59:00', '17:59:02', 0.00),
(8, 6, '2025-09-22', '18:05:55', '18:06:55', 0.02),
(9, 6, '2025-09-22', '18:07:09', '20:07:14', 2.00);

-- --------------------------------------------------------

--
-- Table structure for table `caja_detalle`
--

CREATE TABLE `caja_detalle` (
  `id_detalle` int NOT NULL,
  `id_movimiento` int NOT NULL,
  `id_producto` int NOT NULL,
  `cantidad` int NOT NULL,
  `precio_unitario` decimal(10,2) NOT NULL,
  `monto` decimal(10,2) GENERATED ALWAYS AS ((`cantidad` * `precio_unitario`)) STORED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `caja_detalle`
--

INSERT INTO `caja_detalle` (`id_detalle`, `id_movimiento`, `id_producto`, `cantidad`, `precio_unitario`) VALUES
(1, 4, 1, 2, 15000.00),
(3, 5, 1, 2, 15000.00),
(4, 5, 2, 1, 2000.00),
(5, 6, 1, 2, 15000.00),
(7, 7, 1, 2, 15000.00),
(8, 7, 2, 1, 2000.00),
(9, 9, 1, 1, 15000.00),
(10, 9, 2, 1, 2000.00),
(11, 10, 1, 1, 15000.00),
(12, 10, 2, 1, 2000.00),
(13, 11, 1, 1, 15000.00),
(14, 11, 2, 1, 2000.00),
(15, 14, 1, 1, 15000.00),
(16, 14, 2, 1, 2000.00),
(17, 15, 2, 2, 2000.00),
(18, 15, 1, 1, 15000.00),
(19, 16, 1, 3, 15000.00),
(20, 17, 1, 2, 15000.00),
(21, 17, 2, 3, 2000.00),
(22, 18, 1, 3, 15000.00),
(23, 19, 2, 1, 2000.00),
(24, 20, 1, 1, 15000.00),
(25, 22, 1, 1, 15000.00),
(26, 22, 2, 1, 2000.00),
(27, 23, 1, 5, 15000.00),
(28, 25, 1, 6, 15000.00);

--
-- Triggers `caja_detalle`
--
DELIMITER $$
CREATE TRIGGER `trg_check_stock_before_insert` BEFORE INSERT ON `caja_detalle` FOR EACH ROW BEGIN
    DECLARE v_tipo ENUM('Ingreso','Egreso');
    DECLARE v_stock_actual INT;

    -- Obtenemos el tipo del movimiento
    SELECT tipo INTO v_tipo
    FROM caja_movimientos
    WHERE id_movimiento = NEW.id_movimiento;

    -- Si es Ingreso (venta), verificamos stock
    IF v_tipo = 'Ingreso' THEN
        SELECT stock INTO v_stock_actual
        FROM productos
        WHERE id_producto = NEW.id_producto;

        IF v_stock_actual < NEW.cantidad THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock insuficiente para realizar la venta';
        END IF;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_check_stock_before_update` BEFORE UPDATE ON `caja_detalle` FOR EACH ROW BEGIN
    DECLARE v_tipo ENUM('Ingreso','Egreso');
    DECLARE v_stock_actual INT;

    SELECT tipo INTO v_tipo
    FROM caja_movimientos
    WHERE id_movimiento = NEW.id_movimiento;

    IF v_tipo = 'Ingreso' THEN
        SELECT stock INTO v_stock_actual
        FROM productos
        WHERE id_producto = NEW.id_producto;

        -- Ajustamos stock considerando que ya había OLD.cantidad reservada
        IF v_stock_actual + OLD.cantidad < NEW.cantidad THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock insuficiente para actualizar la venta';
        END IF;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_update_stock_after_delete` AFTER DELETE ON `caja_detalle` FOR EACH ROW BEGIN
    DECLARE v_tipo ENUM('Ingreso','Egreso');

    SELECT tipo INTO v_tipo
    FROM caja_movimientos
    WHERE id_movimiento = OLD.id_movimiento;

    -- Si era Ingreso (venta) => devolvemos stock
    IF v_tipo = 'Ingreso' THEN
        UPDATE productos
        SET stock = stock + OLD.cantidad
        WHERE id_producto = OLD.id_producto;
    END IF;

    -- Si era Egreso (compra/entrada) => quitamos stock
    IF v_tipo = 'Egreso' THEN
        UPDATE productos
        SET stock = stock - OLD.cantidad
        WHERE id_producto = OLD.id_producto;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_update_stock_after_insert` AFTER INSERT ON `caja_detalle` FOR EACH ROW BEGIN
    DECLARE v_tipo ENUM('Ingreso','Egreso');

    -- Obtenemos el tipo del movimiento
    SELECT tipo INTO v_tipo
    FROM caja_movimientos
    WHERE id_movimiento = NEW.id_movimiento;

    -- Si es Ingreso (venta) => restar stock
    IF v_tipo = 'Ingreso' THEN
        UPDATE productos
        SET stock = stock - NEW.cantidad
        WHERE id_producto = NEW.id_producto;
    END IF;

    -- Si es Egreso (compra/entrada) => sumar stock
    IF v_tipo = 'Egreso' THEN
        UPDATE productos
        SET stock = stock + NEW.cantidad
        WHERE id_producto = NEW.id_producto;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_update_stock_after_update` AFTER UPDATE ON `caja_detalle` FOR EACH ROW BEGIN
    DECLARE v_tipo ENUM('Ingreso','Egreso');

    SELECT tipo INTO v_tipo
    FROM caja_movimientos
    WHERE id_movimiento = NEW.id_movimiento;

    -- Revertimos la cantidad anterior
    IF v_tipo = 'Ingreso' THEN
        UPDATE productos
        SET stock = stock + OLD.cantidad
        WHERE id_producto = OLD.id_producto;
    ELSEIF v_tipo = 'Egreso' THEN
        UPDATE productos
        SET stock = stock - OLD.cantidad
        WHERE id_producto = OLD.id_producto;
    END IF;

    -- Aplicamos la nueva cantidad
    IF v_tipo = 'Ingreso' THEN
        UPDATE productos
        SET stock = stock - NEW.cantidad
        WHERE id_producto = NEW.id_producto;
    ELSEIF v_tipo = 'Egreso' THEN
        UPDATE productos
        SET stock = stock + NEW.cantidad
        WHERE id_producto = NEW.id_producto;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `caja_movimientos`
--

CREATE TABLE `caja_movimientos` (
  `id_movimiento` int NOT NULL,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tipo` enum('ingreso','egreso') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `concepto` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `metodo_pago` enum('efectivo','transferencia') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `pagado` tinyint(1) DEFAULT '1',
  `id_usuario` int DEFAULT NULL,
  `id_cuota` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `caja_movimientos`
--

INSERT INTO `caja_movimientos` (`id_movimiento`, `fecha`, `tipo`, `concepto`, `metodo_pago`, `monto`, `pagado`, `id_usuario`, `id_cuota`) VALUES
(4, '2025-08-19 01:48:36', 'ingreso', 'Compra kiosco', 'efectivo', 0.00, 1, 6, NULL),
(5, '2025-08-19 01:49:02', 'ingreso', 'Compra kiosco', 'efectivo', 32000.00, 1, 6, NULL),
(6, '2025-08-19 01:52:11', 'ingreso', 'Compra kiosco', 'efectivo', 0.00, 1, 6, NULL),
(7, '2025-08-19 01:52:24', 'ingreso', 'Compra kiosco', 'efectivo', 32000.00, 1, 6, NULL),
(9, '2025-08-19 02:25:18', 'ingreso', 'Venta de productos', 'efectivo', 17000.00, 1, 6, NULL),
(10, '2025-08-19 02:25:24', 'ingreso', 'Venta de productos', 'efectivo', 17000.00, 1, 6, NULL),
(11, '2025-08-19 14:54:50', 'ingreso', 'Venta de productos', 'efectivo', 17000.00, 1, 6, NULL),
(13, '2025-08-21 15:23:22', 'ingreso', 'cuota', 'efectivo', 24998.00, 1, 4, 8),
(14, '2025-08-31 18:33:41', 'ingreso', 'Venta de productos', 'efectivo', 17000.00, 1, 6, NULL),
(15, '2025-09-01 16:03:57', 'egreso', 'Kiosco', 'efectivo', 19000.00, 1, 6, NULL),
(16, '2025-09-01 16:08:59', 'ingreso', 'Prote', 'transferencia', 45000.00, 1, 6, NULL),
(17, '2025-09-01 16:09:29', 'ingreso', 'Prote y kisco', 'transferencia', 36000.00, 1, 6, NULL),
(18, '2025-09-01 23:10:43', 'ingreso', 'Prote', 'efectivo', 45000.00, 1, 7, NULL),
(19, '2025-09-01 23:11:25', 'ingreso', 'Kiosco', 'efectivo', 2000.00, 0, 7, NULL),
(20, '2025-09-01 23:49:35', 'ingreso', 'NO C', 'efectivo', 15000.00, 1, 7, NULL),
(21, '2025-09-01 23:51:54', 'ingreso', 'cuota', 'transferencia', 20000.00, 1, 4, 9),
(22, '2025-09-02 14:51:03', 'ingreso', 'Prote', 'efectivo', 17000.00, 1, 7, NULL),
(23, '2025-09-22 21:38:11', 'egreso', 'distribuidora prote', 'efectivo', 75000.00, 1, 6, NULL),
(24, '2025-09-22 21:47:05', 'egreso', 'Luz', 'efectivo', 50000.00, 1, 6, NULL),
(25, '2025-09-22 21:48:37', 'ingreso', 'Prote', 'efectivo', 90000.00, 1, 6, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `clases`
--

CREATE TABLE `clases` (
  `id_clase` int NOT NULL,
  `id_disciplina` int DEFAULT NULL,
  `id_dia` int DEFAULT NULL,
  `hora` time DEFAULT NULL,
  `capacidad_max` int DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `clases`
--

INSERT INTO `clases` (`id_clase`, `id_disciplina`, `id_dia`, `hora`, `capacidad_max`, `activa`) VALUES
(1, 1, 1, '06:00:00', 20, 1),
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
-- Table structure for table `clases_usuarios`
--

CREATE TABLE `clases_usuarios` (
  `id_clase` int NOT NULL,
  `id_usuario` int NOT NULL,
  `presente` tinyint(1) DEFAULT NULL,
  `fecha` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `clases_usuarios`
--

INSERT INTO `clases_usuarios` (`id_clase`, `id_usuario`, `presente`, `fecha`) VALUES
(1, 4, NULL, '2025-05-26'),
(1, 4, NULL, '2025-09-01'),
(2, 4, NULL, '2025-05-27'),
(2, 4, NULL, '2025-09-02'),
(3, 4, NULL, '2025-09-03'),
(4, 4, NULL, '2025-09-04'),
(5, 4, NULL, '2025-08-22'),
(6, 4, NULL, '2025-08-23'),
(7, 4, NULL, '2025-05-26'),
(8, 4, NULL, '2025-09-02'),
(10, 4, NULL, '2025-06-05');

-- --------------------------------------------------------

--
-- Table structure for table `cuotas`
--

CREATE TABLE `cuotas` (
  `id_cuota` int NOT NULL,
  `id_usuario` int NOT NULL,
  `id_plan` int NOT NULL,
  `fecha_pago` date DEFAULT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  `estado_pago` enum('Paga','Pendiente','Vencida') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'Paga',
  `creditos_total` int NOT NULL,
  `creditos_disponibles` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `cuotas`
--

INSERT INTO `cuotas` (`id_cuota`, `id_usuario`, `id_plan`, `fecha_pago`, `fecha_vencimiento`, `estado_pago`, `creditos_total`, `creditos_disponibles`) VALUES
(1, 4, 1, '2025-05-12', '2025-06-11', 'Paga', 8, 28),
(6, 6, 1, '2025-08-19', '2025-09-19', 'Paga', 8, 8),
(8, 4, 5, '2025-08-21', '2025-09-21', 'Paga', 23, 21),
(9, 4, 1, '2025-09-01', '2025-10-01', 'Paga', 8, 3);

-- --------------------------------------------------------

--
-- Table structure for table `datos_personales`
--

CREATE TABLE `datos_personales` (
  `id_usuario` int NOT NULL,
  `dni` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `celular` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `datos_personales`
--

INSERT INTO `datos_personales` (`id_usuario`, `dni`, `celular`) VALUES
(4, '46999888', '11111111'),
(6, '41991328', '2364310386'),
(7, '41717495', '1199999999'),
(8, '345678495', '2345687964'),
(9, '37685437', '2364536786'),
(10, '34567685', '2364532432');

-- --------------------------------------------------------

--
-- Table structure for table `dias`
--

CREATE TABLE `dias` (
  `id_dia` int NOT NULL,
  `dia` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `dias`
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
-- Table structure for table `disciplinas`
--

CREATE TABLE `disciplinas` (
  `id_disciplina` int NOT NULL,
  `disciplina` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `disciplinas`
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
-- Table structure for table `ejercicios`
--

CREATE TABLE `ejercicios` (
  `id_ejercicio` int NOT NULL,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `link` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ejercicios`
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
-- Table structure for table `ejercicios_usuarios_rm`
--

CREATE TABLE `ejercicios_usuarios_rm` (
  `id_usuario` int NOT NULL,
  `id_ejercicio` int NOT NULL,
  `peso` decimal(10,2) DEFAULT NULL COMMENT 'Peso máximo en kg',
  `repeticiones` int NOT NULL,
  `fecha_actualizacion` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `notas` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ejercicios_usuarios_rm`
--

INSERT INTO `ejercicios_usuarios_rm` (`id_usuario`, `id_ejercicio`, `peso`, `repeticiones`, `fecha_actualizacion`, `notas`) VALUES
(4, 1, 90.00, 1, '2025-08-22 00:11:30', '');

-- --------------------------------------------------------

--
-- Table structure for table `estados`
--

CREATE TABLE `estados` (
  `id_estado` int NOT NULL,
  `estado` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `estados`
--

INSERT INTO `estados` (`id_estado`, `estado`) VALUES
(1, 'Activo'),
(2, 'Pausado'),
(3, 'Vencido');

-- --------------------------------------------------------

--
-- Table structure for table `horas_pactadas`
--

CREATE TABLE `horas_pactadas` (
  `id_pactado` int NOT NULL,
  `id_usuario` int NOT NULL,
  `horas_pactadas` int NOT NULL,
  `tarifa` decimal(10,2) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `horas_pactadas`
--

INSERT INTO `horas_pactadas` (`id_pactado`, `id_usuario`, `horas_pactadas`, `tarifa`, `active`) VALUES
(1, 6, 45, 7800.00, 1),
(2, 9, 40, 6500.00, 1);

-- --------------------------------------------------------

--
-- Table structure for table `liquidaciones_profes`
--

CREATE TABLE `liquidaciones_profes` (
  `id_liquidacion` int NOT NULL,
  `id_usuario` int NOT NULL,
  `periodo` varchar(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `horas_pactadas` int NOT NULL,
  `horas_trabajadas` int NOT NULL,
  `horas_pagadas` int NOT NULL,
  `total` decimal(10,2) NOT NULL,
  `fecha_liquidacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `liquidaciones_profes`
--

INSERT INTO `liquidaciones_profes` (`id_liquidacion`, `id_usuario`, `periodo`, `horas_pactadas`, `horas_trabajadas`, `horas_pagadas`, `total`, `fecha_liquidacion`) VALUES
(2, 6, '2025-08', 45, 8, 16, 124800.00, '2025-08-26 00:25:34'),
(3, 9, '2025-08', 40, 16, 20, 130000.00, '2025-08-26 15:51:11');

-- --------------------------------------------------------

--
-- Table structure for table `planes`
--

CREATE TABLE `planes` (
  `id_plan` int NOT NULL,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `descripcion` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `monto` decimal(10,2) NOT NULL,
  `creditos_total` int NOT NULL,
  `activa` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `planes`
--

INSERT INTO `planes` (`id_plan`, `nombre`, `descripcion`, `monto`, `creditos_total`, `activa`) VALUES
(1, 'Plan 8c multidisciplina', 'Permite asistir dos veces por semana a dos disciplinas', 20000.00, 8, 1),
(5, 'Crossfit Semanal', '24 creditos para Crossfit', 24998.00, 24, 1);

-- --------------------------------------------------------

--
-- Table structure for table `planes_disciplinas`
--

CREATE TABLE `planes_disciplinas` (
  `id_plan` int NOT NULL,
  `id_disciplina` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `planes_disciplinas`
--

INSERT INTO `planes_disciplinas` (`id_plan`, `id_disciplina`) VALUES
(1, 1),
(5, 1),
(1, 2),
(5, 4);

-- --------------------------------------------------------

--
-- Table structure for table `productos`
--

CREATE TABLE `productos` (
  `id_producto` int NOT NULL,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `descripcion` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `precio` decimal(10,2) NOT NULL,
  `stock` int NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `productos`
--

INSERT INTO `productos` (`id_producto`, `nombre`, `descripcion`, `precio`, `stock`) VALUES
(1, 'Proteína Whey', 'Suplemento de proteína en polvo', 30000.00, 2),
(2, 'Powerade Frutos Rojos', 'Bebida isotónica', 2000.00, 12),
(3, 'Barrita proteica', 'barrita chocolate', 3000.00, 10);

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

CREATE TABLE `roles` (
  `id_rol` int NOT NULL,
  `rol` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`id_rol`, `rol`) VALUES
(1, 'Administrador'),
(2, 'Profesor'),
(3, 'Alumno');

-- --------------------------------------------------------

--
-- Table structure for table `rutina`
--

CREATE TABLE `rutina` (
  `id_rutina` int NOT NULL,
  `id_usuario` int NOT NULL,
  `activa` tinyint(1) DEFAULT '1',
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rutina`
--

INSERT INTO `rutina` (`id_rutina`, `id_usuario`, `activa`, `nombre`) VALUES
(2, 4, 1, 'Piernas');

-- --------------------------------------------------------

--
-- Table structure for table `rutina_ejercicios`
--

CREATE TABLE `rutina_ejercicios` (
  `id_rutina` int NOT NULL,
  `id_ejercicio` int NOT NULL,
  `dia` tinyint NOT NULL,
  `orden` int DEFAULT '1',
  `rondas` int DEFAULT '1',
  `repeticiones` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rutina_ejercicios`
--

INSERT INTO `rutina_ejercicios` (`id_rutina`, `id_ejercicio`, `dia`, `orden`, `rondas`, `repeticiones`) VALUES
(2, 3, 2, 1, 4, '10'),
(2, 5, 2, 2, 3, '12');

-- --------------------------------------------------------

--
-- Table structure for table `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` int NOT NULL,
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `id_rol` int DEFAULT NULL,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `id_estado` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `email`, `password`, `id_rol`, `nombre`, `id_estado`) VALUES
(4, 'lau@example.com', '$2b$10$JNw8UvDnif80vSmv1aCdqe0CJzLq.dZ5DyFagSAWUE2UGvPg6u9RS', 3, 'Lautaro Bustamante', 1),
(6, 'solsv7@gmail.com', '$2b$10$JucDwzLHnEQzABUNumPYf.IgNDbtqD9WfPm.K1l2A8ve5j8d35bny', 2, 'Sol', 1),
(7, 'ivomonti1@gmail.com', '$2b$10$JY0E6Fs3l/t8YNp0LRU9n.urFfsF8RFYial53cg/BMTgNmAS565Du', 1, 'Ivo', 1),
(8, 'Ondinamonti@gmail.com', '$2b$10$q.27TtwF.1TE1JrEZ/b4dOxpbdfOAEBw.QsgxSjF1atSh/3Pk87OW', 1, 'Ondina', 1),
(9, 'flaviacalde@gmail.com', '$2b$10$0ughXdWBz5/305dM3U4sLu/DhvN0f4KmIynmWBItqp/ehXTQ1fhe.', 2, 'Flavia Calderon', 1),
(10, 'agusf@gmail.com', '$2b$10$puRGvIfbzdiNaYnVfI9BsuqS43MkyIa5XFH9b6IEduRjgupnFID.G', 3, 'Agustin Fernandez', 2);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `asistencia_profes`
--
ALTER TABLE `asistencia_profes`
  ADD PRIMARY KEY (`id_asistencia`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indexes for table `caja_detalle`
--
ALTER TABLE `caja_detalle`
  ADD PRIMARY KEY (`id_detalle`),
  ADD KEY `id_movimiento` (`id_movimiento`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indexes for table `caja_movimientos`
--
ALTER TABLE `caja_movimientos`
  ADD PRIMARY KEY (`id_movimiento`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_cuota` (`id_cuota`);

--
-- Indexes for table `clases`
--
ALTER TABLE `clases`
  ADD PRIMARY KEY (`id_clase`),
  ADD KEY `id_disciplina` (`id_disciplina`),
  ADD KEY `id_dia` (`id_dia`);

--
-- Indexes for table `clases_usuarios`
--
ALTER TABLE `clases_usuarios`
  ADD PRIMARY KEY (`id_clase`,`id_usuario`,`fecha`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indexes for table `cuotas`
--
ALTER TABLE `cuotas`
  ADD PRIMARY KEY (`id_cuota`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_plan` (`id_plan`);

--
-- Indexes for table `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD PRIMARY KEY (`id_usuario`);

--
-- Indexes for table `dias`
--
ALTER TABLE `dias`
  ADD PRIMARY KEY (`id_dia`);

--
-- Indexes for table `disciplinas`
--
ALTER TABLE `disciplinas`
  ADD PRIMARY KEY (`id_disciplina`);

--
-- Indexes for table `ejercicios`
--
ALTER TABLE `ejercicios`
  ADD PRIMARY KEY (`id_ejercicio`);

--
-- Indexes for table `ejercicios_usuarios_rm`
--
ALTER TABLE `ejercicios_usuarios_rm`
  ADD PRIMARY KEY (`id_usuario`,`id_ejercicio`,`repeticiones`),
  ADD KEY `id_ejercicio` (`id_ejercicio`);

--
-- Indexes for table `estados`
--
ALTER TABLE `estados`
  ADD PRIMARY KEY (`id_estado`);

--
-- Indexes for table `horas_pactadas`
--
ALTER TABLE `horas_pactadas`
  ADD PRIMARY KEY (`id_pactado`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indexes for table `liquidaciones_profes`
--
ALTER TABLE `liquidaciones_profes`
  ADD PRIMARY KEY (`id_liquidacion`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indexes for table `planes`
--
ALTER TABLE `planes`
  ADD PRIMARY KEY (`id_plan`);

--
-- Indexes for table `planes_disciplinas`
--
ALTER TABLE `planes_disciplinas`
  ADD PRIMARY KEY (`id_plan`,`id_disciplina`),
  ADD KEY `id_disciplina` (`id_disciplina`);

--
-- Indexes for table `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`);

--
-- Indexes for table `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id_rol`);

--
-- Indexes for table `rutina`
--
ALTER TABLE `rutina`
  ADD PRIMARY KEY (`id_rutina`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indexes for table `rutina_ejercicios`
--
ALTER TABLE `rutina_ejercicios`
  ADD PRIMARY KEY (`id_rutina`,`id_ejercicio`,`dia`),
  ADD KEY `id_ejercicio` (`id_ejercicio`);

--
-- Indexes for table `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD KEY `fk_usuario_rol` (`id_rol`),
  ADD KEY `fk_usuario_estado` (`id_estado`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `asistencia_profes`
--
ALTER TABLE `asistencia_profes`
  MODIFY `id_asistencia` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `caja_detalle`
--
ALTER TABLE `caja_detalle`
  MODIFY `id_detalle` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT for table `caja_movimientos`
--
ALTER TABLE `caja_movimientos`
  MODIFY `id_movimiento` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `clases`
--
ALTER TABLE `clases`
  MODIFY `id_clase` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=32;

--
-- AUTO_INCREMENT for table `cuotas`
--
ALTER TABLE `cuotas`
  MODIFY `id_cuota` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `dias`
--
ALTER TABLE `dias`
  MODIFY `id_dia` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `disciplinas`
--
ALTER TABLE `disciplinas`
  MODIFY `id_disciplina` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `ejercicios`
--
ALTER TABLE `ejercicios`
  MODIFY `id_ejercicio` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `estados`
--
ALTER TABLE `estados`
  MODIFY `id_estado` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `horas_pactadas`
--
ALTER TABLE `horas_pactadas`
  MODIFY `id_pactado` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `liquidaciones_profes`
--
ALTER TABLE `liquidaciones_profes`
  MODIFY `id_liquidacion` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `planes`
--
ALTER TABLE `planes`
  MODIFY `id_plan` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `roles`
--
ALTER TABLE `roles`
  MODIFY `id_rol` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `rutina`
--
ALTER TABLE `rutina`
  MODIFY `id_rutina` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `asistencia_profes`
--
ALTER TABLE `asistencia_profes`
  ADD CONSTRAINT `asistencia_profes_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Constraints for table `caja_detalle`
--
ALTER TABLE `caja_detalle`
  ADD CONSTRAINT `caja_detalle_ibfk_1` FOREIGN KEY (`id_movimiento`) REFERENCES `caja_movimientos` (`id_movimiento`),
  ADD CONSTRAINT `caja_detalle_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`);

--
-- Constraints for table `caja_movimientos`
--
ALTER TABLE `caja_movimientos`
  ADD CONSTRAINT `caja_movimientos_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `caja_movimientos_ibfk_2` FOREIGN KEY (`id_cuota`) REFERENCES `cuotas` (`id_cuota`);

--
-- Constraints for table `clases`
--
ALTER TABLE `clases`
  ADD CONSTRAINT `clases_ibfk_1` FOREIGN KEY (`id_disciplina`) REFERENCES `disciplinas` (`id_disciplina`),
  ADD CONSTRAINT `clases_ibfk_2` FOREIGN KEY (`id_dia`) REFERENCES `dias` (`id_dia`);

--
-- Constraints for table `clases_usuarios`
--
ALTER TABLE `clases_usuarios`
  ADD CONSTRAINT `clases_usuarios_ibfk_1` FOREIGN KEY (`id_clase`) REFERENCES `clases` (`id_clase`),
  ADD CONSTRAINT `clases_usuarios_ibfk_2` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Constraints for table `cuotas`
--
ALTER TABLE `cuotas`
  ADD CONSTRAINT `cuotas_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `cuotas_ibfk_2` FOREIGN KEY (`id_plan`) REFERENCES `planes` (`id_plan`);

--
-- Constraints for table `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD CONSTRAINT `datos_personales_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Constraints for table `ejercicios_usuarios_rm`
--
ALTER TABLE `ejercicios_usuarios_rm`
  ADD CONSTRAINT `ejercicios_usuarios_rm_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `ejercicios_usuarios_rm_ibfk_2` FOREIGN KEY (`id_ejercicio`) REFERENCES `ejercicios` (`id_ejercicio`);

--
-- Constraints for table `horas_pactadas`
--
ALTER TABLE `horas_pactadas`
  ADD CONSTRAINT `horas_pactadas_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Constraints for table `liquidaciones_profes`
--
ALTER TABLE `liquidaciones_profes`
  ADD CONSTRAINT `liquidaciones_profes_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Constraints for table `planes_disciplinas`
--
ALTER TABLE `planes_disciplinas`
  ADD CONSTRAINT `planes_disciplinas_ibfk_1` FOREIGN KEY (`id_plan`) REFERENCES `planes` (`id_plan`),
  ADD CONSTRAINT `planes_disciplinas_ibfk_2` FOREIGN KEY (`id_disciplina`) REFERENCES `disciplinas` (`id_disciplina`);

--
-- Constraints for table `rutina`
--
ALTER TABLE `rutina`
  ADD CONSTRAINT `rutina_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Constraints for table `rutina_ejercicios`
--
ALTER TABLE `rutina_ejercicios`
  ADD CONSTRAINT `rutina_ejercicios_ibfk_1` FOREIGN KEY (`id_rutina`) REFERENCES `rutina` (`id_rutina`) ON DELETE CASCADE,
  ADD CONSTRAINT `rutina_ejercicios_ibfk_2` FOREIGN KEY (`id_ejercicio`) REFERENCES `ejercicios` (`id_ejercicio`) ON DELETE CASCADE;

--
-- Constraints for table `usuarios`
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
