-- CASO 1: LISTADO DE CLIENTES CON RANGO DE RENTA
SELECT TO_CHAR(numrut_cli, '99G999G999') || 
    '-' || 
    dvrut_cli AS "RUT Cliente",
    -- Formateo a texto capital
    INITCAP(nombre_cli) ||
    ' ' ||
    INITCAP(appaterno_cli) ||
    ' ' ||
    INITCAP(apmaterno_cli) AS "Nombre Completo Cliente",
    INITCAP(direccion_cli) AS "Dirección Cliente",
    -- Formateo a miles y signo moneda
    TO_CHAR(renta_cli, '$999G999G999') AS "Renta Cliente",
    SUBSTR(LPAD(TO_CHAR(celular_cli), 9, '0'), 1, 2) || 
    '-' || 
    SUBSTR(LPAD(TO_CHAR(celular_cli), 9, '0'), 3, 3) || 
    '-' ||
    SUBSTR(LPAD(TO_CHAR(celular_cli), 9, '0'), 6, 4)
    AS "Celular Cliente",
    -- Clasificación de renta por tramo
    CASE 
      WHEN renta_cli > 500000 THEN 'TRAMO 1'
      WHEN renta_cli BETWEEN 400000 AND 500000 THEN 'TRAMO 2'
      WHEN renta_cli BETWEEN 200000 AND 399999 THEN 'TRAMO 3'
    ELSE 'TRAMO 4'
    END AS "Tramo Renta Cliente"      
FROM cliente
WHERE renta_cli BETWEEN &RENTA_MINIMA AND &RENTA_MAXIMA
    AND celular_cli IS NOT NULL
ORDER BY nombre_cli, appaterno_cli, apmaterno_cli;
  
-- CASO 2: SUELDO PROMEDIO POR CATEGORIA DE EMPLEADO
SELECT e.id_categoria_emp AS "CODIGO_CATEGORIA",
    c.desc_categoria_emp AS "DESCRIPCION_CATEGORIA",
    COUNT(e.numrut_emp) AS "CANTIDAD_EMPLEADOS",
    s.desc_sucursal AS "SUCURSAL",
    -- Cálculo de promedio de sueldos formateado
    TO_CHAR(AVG(e.sueldo_emp), 'L999G999G990') AS "SUELDO_PROMEDIO"
FROM empleado e,
    categoria_empleado c, 
    sucursal s
WHERE 
    e.id_categoria_emp = c.id_categoria_emp
    AND e.id_sucursal = s.id_sucursal     
GROUP BY 
    e.id_categoria_emp, c.desc_categoria_emp, s.desc_sucursal
HAVING 
    AVG(e.sueldo_emp) > &SUELDO_PROMEDIO_MINIMO      
ORDER BY 
    AVG(e.sueldo_emp) DESC;  

-- CASO 3: ARRIENDO PROMEDIO POR TIPO DE PROPIEDAD
SELECT LPAD(p.id_tipo_propiedad, 12) AS "CODIGO_TIPO",
    t.desc_tipo_propiedad AS "DESCRIPCION_TIPO",
    COUNT(p.nro_propiedad) AS "TOTAL PROPIEDADES",
    -- Cálculo promedio de arriendo y promedio de superficie formateados
    TO_CHAR(AVG(p.valor_arriendo), 'L999G999G990') AS "PROMEDIO_ARRIENDO",
    LPAD(TO_CHAR(AVG(p.superficie), '99D99'), 20) AS "PROMEDIO_SUPERFICIE",
    -- Cálculo del valor promedio de arriendo por m2 formateado
    TO_CHAR(ROUND(AVG(p.valor_arriendo / p.superficie)), 'L99G999G990') AS "VALOR_ARRIENDO_M2",
    -- Clasificacion por categorías según valor promedio de m2
    CASE 
        WHEN AVG(p.valor_arriendo / p.superficie) < 5000 THEN 'Económico'
        WHEN AVG(p.valor_arriendo / p.superficie) BETWEEN 5000 AND 10000 THEN 'Medio'
        ELSE 'Alto'
    END AS "CLASIFICACION"
FROM propiedad p,
     tipo_propiedad t
WHERE 
    p.id_tipo_propiedad = t.id_tipo_propiedad          
GROUP BY
    p.id_tipo_propiedad, t.desc_tipo_propiedad
HAVING AVG(p.valor_arriendo / p.superficie) > 1000     
ORDER BY AVG(valor_arriendo / superficie) DESC;
