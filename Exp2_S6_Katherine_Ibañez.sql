
-- CASO 1: Reportería de Asesorías
SELECT
    t1."ID",
    INITCAP(p.appaterno || ' ' || p.apmaterno || ' ' || p.nombre) AS "PROFESIONAL",
    --UNION ALL
    SUM(t1."NRO ASESORIA BANCA") AS "NRO ASESORIA BANCA",
    TO_CHAR(SUM(t1."MONTO_TOTAL_BANCA"), 'FM$999G999G999') AS "MONTO_TOTAL_BANCA",
    SUM(t1."NRO ASESORIA RETAIL") AS "NRO ASESORIA RETAIL",
    TO_CHAR(SUM(t1."MONTO_TOTAL_RETAIL"), 'FM$999G999G999') AS "MONTO_TOTAL_RETAIL",
    SUM(t1."TOTAL ASESORIAS") AS "TOTAL ASESORIAS",
    TO_CHAR(SUM(t1."TOTAL HONORARIOS"), 'FM$999G999G999') AS "TOTAL HONORARIOS"
FROM
    profesional p
JOIN
    (
        -- Consulta para obtener los datos de BANCA
        SELECT
            a.id_profesional AS "ID",
            COUNT(a.cod_empresa) AS "NRO ASESORIA BANCA",
            ROUND(SUM(a.honorario)) AS "MONTO_TOTAL_BANCA",
            0 AS "NRO ASESORIA RETAIL",
            0 AS "MONTO_TOTAL_RETAIL",
            COUNT(a.cod_empresa) AS "TOTAL ASESORIAS",
            ROUND(SUM(a.honorario)) AS "TOTAL HONORARIOS"
        FROM
            asesoria a
        JOIN
            empresa e ON a.cod_empresa = e.cod_empresa
        WHERE
            e.cod_sector = 3
        GROUP BY
            a.id_profesional
        UNION ALL
        -- Consulta para obtener los datos de RETAIL 
        SELECT
            a.id_profesional AS "ID",
            0 AS "NRO ASESORIA BANCA",
            0 AS "MONTO_TOTAL_BANCA",
            COUNT(a.cod_empresa) AS "NRO ASESORIA RETAIL",
            ROUND(SUM(a.honorario)) AS "MONTO_TOTAL_RETAIL",
            COUNT(a.cod_empresa) AS "TOTAL ASESORIAS",
            ROUND(SUM(a.honorario)) AS "TOTAL HONORARIOS"
        FROM
            asesoria a
        JOIN
            empresa e ON a.cod_empresa = e.cod_empresa
        WHERE
            e.cod_sector = 4
        GROUP BY
            a.id_profesional
    ) t1 ON p.id_profesional = t1."ID"
WHERE
    -- Restriccion de datos con subconsultas anidadas
    p.id_profesional IN (
        -- Subconsulta 1
        SELECT a_banca.id_profesional FROM asesoria a_banca JOIN empresa e_banca ON a_banca.cod_empresa = e_banca.cod_empresa WHERE e_banca.cod_sector = 3
    )
    AND p.id_profesional IN (
        -- Subconsulta 2
        SELECT a_retail.id_profesional FROM asesoria a_retail JOIN empresa e_retail ON a_retail.cod_empresa = e_retail.cod_empresa WHERE e_retail.cod_sector = 4
    )
GROUP BY
    t1."ID",
    p.appaterno,
    p.apmaterno,
    p.nombre
ORDER BY
    "ID" ASC;
      
-- CASO 2: Resumen de Honorarios
DROP TABLE REPORTE_MES CASCADE CONSTRAINTS;

CREATE TABLE REPORTE_MES AS
SELECT
    p.id_profesional AS "ID_PROF",
    INITCAP(p.appaterno || ' ' || p.apmaterno || ' ' || p.nombre) AS "NOMBRE_COMPLETO",
    pro.nombre_profesion AS "NOMBRE_PROFESION",
    c.nom_comuna AS "NOM_COMUNA",
    COUNT(a.cod_empresa) AS "NRO_ASESORIAS",
    -- redondeado a entero y formateado con separadores de miles
    TO_CHAR(ROUND(SUM(a.honorario)), 'FM999999999') AS "MONTO_TOTAL_HONORARIOS",
    TO_CHAR(ROUND(AVG(a.honorario)), 'FM999999999') AS "PROMEDIO_HONORARIO",
    TO_CHAR(ROUND(MIN(a.honorario)), 'FM999999999') AS "HONORARIO_MINIMO",
    TO_CHAR(ROUND(MAX(a.honorario)), 'FM999999999') AS "HONORARIO_MAXIMO"
FROM
    profesional p
JOIN
    asesoria a ON p.id_profesional = a.id_profesional
JOIN
    profesion pro ON p.cod_profesion = pro.cod_profesion
-- para profesionales sin comuna
LEFT JOIN
    comuna c ON p.cod_comuna = c.cod_comuna 
WHERE
    -- restriccion de datos en ABRIL 2024
    EXTRACT(YEAR FROM a.fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
    AND EXTRACT(MONTH FROM a.fin_asesoria) = 4
GROUP BY
    p.id_profesional,
    p.appaterno,
    p.apmaterno,
    p.nombre,
    pro.nombre_profesion,
    c.nom_comuna
ORDER BY
    p.id_profesional ASC;

-- CASO 3: Modificacion de Honorarios
DROP TABLE RESUMEN_COMPRA_AVANCE_PUNTOS CASCADE CONSTRAINTS;
-- Creacion de la tabla
CREATE TABLE RESUMEN_COMPRA_AVANCE_PUNTOS (
    id_profesional NUMBER PRIMARY KEY,
    puntos NUMBER 
);

-- Insercion de sueldo base
INSERT INTO RESUMEN_COMPRA_AVANCE_PUNTOS (id_profesional, puntos)
SELECT id_profesional, sueldo FROM profesional;

COMMIT;

-- Reporte antes de la actualizacion
SELECT
    -- Total de honorarios en el periodo
    TO_CHAR(COALESCE(th.total_honorarios, 0), 'FM999999999') AS "HONORARIO",
    p.id_profesional AS "ID_PROFESIONAL",
    p.numrun_prof AS "NUMRUT_PROF",
    -- Sueldo actual
    TO_CHAR(rcap.puntos, 'FM999999999') AS "SUELDO"
FROM
    profesional p
JOIN
    RESUMEN_COMPRA_AVANCE_PUNTOS rcap ON p.id_profesional = rcap.id_profesional
JOIN
    (
        -- Subconsulta para calcular el total de honorarios en Marzo del año pasado
        SELECT
            id_profesional,
            ROUND(SUM(honorario)) AS total_honorarios
        FROM
            asesoria
        WHERE
            -- Restriccion de Fecha
            EXTRACT(YEAR FROM fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
            AND EXTRACT(MONTH FROM fin_asesoria) = 3
        GROUP BY
            id_profesional
    ) th ON p.id_profesional = th.id_profesional
ORDER BY
    p.id_profesional ASC;
    
-- Proceso de actualizacion del sueldo
UPDATE RESUMEN_COMPRA_AVANCE_PUNTOS rcap
SET rcap.puntos =
    (
        SELECT
            -- Aplicacion del incremento condicional
            ROUND(rcap.puntos * (
                CASE
                    WHEN SUM(a.honorario) < 1000000 THEN 1.10
                    WHEN SUM(a.honorario) >= 1000000 THEN 1.15
                END
            ))
        FROM
            asesoria a
        WHERE
            a.id_profesional = rcap.id_profesional 
            AND EXTRACT(YEAR FROM a.fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
            AND EXTRACT(MONTH FROM a.fin_asesoria) = 3
        GROUP BY
            a.id_profesional
    )
WHERE
    rcap.id_profesional IN
    (
        -- Solo profesionales que finalizaron asesorías en marzo del año pasado
        SELECT
            id_profesional
        FROM
            asesoria
        WHERE
            EXTRACT(YEAR FROM fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
            AND EXTRACT(MONTH FROM fin_asesoria) = 3
    );

COMMIT;

-- Reporte despues de la actualizacion
SELECT
    -- Total de honorarios en el periodo
    TO_CHAR(COALESCE(th.total_honorarios, 0), 'FM999999999') AS "HONORARIO",
    p.id_profesional AS "ID_PROFESIONAL",
    p.numrun_prof AS "NUMRUT_PROF",
    -- Sueldo actualizado
    TO_CHAR(rcap.puntos, 'FM999999999') AS "SUELDO"
FROM
    profesional p
JOIN
    RESUMEN_COMPRA_AVANCE_PUNTOS rcap ON p.id_profesional = rcap.id_profesional
JOIN
    (
        -- Subconsulta para calcular el total de honorarios
        SELECT
            id_profesional,
            ROUND(SUM(honorario)) AS total_honorarios
        FROM
            asesoria
        WHERE
            EXTRACT(YEAR FROM fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
            AND EXTRACT(MONTH FROM fin_asesoria) = 3
        GROUP BY
            id_profesional
    ) th ON p.id_profesional = th.id_profesional
ORDER BY
    p.id_profesional ASC;