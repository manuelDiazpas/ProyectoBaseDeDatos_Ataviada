use ataviada;

-- 1. Consultas

-- Obtener el identificador de los clientes que han comprado algún producto
-- que no tenga telefono
select p.Cliente_codigo_cliente from pedido p 
where p.Cliente_codigo_cliente in (select c2.codigo_cliente from cliente c2 
where c2.telefono is null);

-- ordenar los productos del más caro al más barato que sea menor de 100€ y mayor de 50€
select p.nombre_producto, concat(p.precio, ' €') from producto p
where p.precio between 50.0 and 100.0
order by p.precio desc;

-- nombre de 5 productos pedidos que valgan menos de 10€, ademas de el precio total por todas las unidades pedidas
select p.nombre_producto, lp.cantidad, lp.precio_unidad, concat(lp.cantidad*lp.precio_unidad) as 'Precio total' from linea_pedido lp 
inner join producto p ON lp.Producto_codigo_producto = p.codigo_producto
where lp.precio_unidad <10
limit 5;

-- productos que esten en stock agrupadas en tallas
select s.talla, count(p.codigo_producto) from stock s 
inner join producto p ON s.talla = p.Stock_talla
group by p.Stock_talla;

-- nombre de cliente que reserva un producto en stock + la fecha que se reservó
select c.codigo_cliente, r.fecha_inicio from reserva r 
inner join cliente c ON r.Cliente_codigo_cliente = c.codigo_cliente;

-- 2. Vistas
-- vista de la consulta número 4
create or replace view tallas_productos_stock
as select s.talla, count(p.codigo_producto) from stock s 
inner join producto p ON s.talla = p.Stock_talla
group by p.Stock_talla;

-- vista de la consulta número 1
create or replace view clientes_sin_telefono
as select p.Cliente_codigo_cliente from pedido p 
inner join cliente c ON p.Cliente_codigo_cliente = c.codigo_cliente
where c.telefono is null;

-- 3. Funciones y Procedimientos

-- 3.1 Funciones

-- Funcion que te suma el precio total de dos productos pedidos

drop function suma;

delimiter &&
create Function Suma(p1 int, p2 int)
returns decimal
deterministic
begin
	
	declare pr1 decimal;
	declare pr2 decimal;

	select lp.precio_unidad into pr1 from linea_pedido lp
	where lp.Producto_codigo_producto = p1;

	select lp.precio_unidad into pr2 from linea_pedido lp
	where lp.Producto_codigo_producto = p2;
	
 Return (pr1 + pr2);
end
&&


delimiter ;
select suma(1, 10);

-- Función que devuelve el nombre de un cliente

drop function buscar_nombre_cliente;

delimiter &&
create function buscar_nombre_cliente(cod_cliente int) 
returns varchar(100)
deterministic
begin
    return(SELECT concat_ws(' ', c.nombre, c.apellido) from cliente c where c.codigo_cliente = cod_cliente);
end
&&

delimiter ;
select buscar_nombre_cliente(3);

-- 3.2 Procedimientos

-- cuenta cuantos clientes empiezan con una letra

drop procedure total_clientes_letra;

delimiter &&
CREATE PROCEDURE total_clientes_letra (IN palabra varchar(20))
BEGIN
  SELECT COUNT(*) as 'total' FROM cliente c
  WHERE c.nombre like concat(palabra,'%');
END 
&&

delimiter ;
call total_clientes_letra('q');


-- devuelve el numero de pedidos y reservas realizados por el cliente

drop procedure reservas_pedidos_cliente;

delimiter &&
CREATE PROCEDURE reservas_pedidos_cliente(IN cod int)
BEGIN

	declare reserva int default(select count(r.Cliente_codigo_cliente) from reserva r 
	where r.Cliente_codigo_cliente = cod);
	
	declare pedido int default(select count(p.Cliente_codigo_cliente) from pedido p
	where p.Cliente_codigo_cliente = cod);
	
	
	SELECT concat('El cliente ', buscar_nombre_cliente(cod), ' tiene ', (reserva + pedido), ' reservas y pedidos en total.') as 'Reservas y pedidos totales'
	FROM cliente c 
	limit 1;

END 
&&

delimiter ;
call reservas_pedidos_cliente(571);


-- inserta en una tabla llamada 'reserva_mes_especifico' donde almacena el número de reservas hechas en un mes


DROP TABLE IF EXISTS reserva_mes_especifico;

CREATE TABLE reserva_mes_especifico (
  numeros_reservas INT,
  nombre_mes VARCHAR(45)
);

DROP PROCEDURE IF EXISTS mete_reserva_mes;

DELIMITER &&

CREATE PROCEDURE mete_reserva_mes(IN mes VARCHAR(45))
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE total_personas INT;
  DECLARE mes_nombre VARCHAR(45);
  
  -- Crea un cursor cursor que selecciona todas las personas que hayan reservado en el dia indicado
  DECLARE cliente_mes CURSOR FOR
    SELECT COUNT(*) AS total_personas, MONTHNAME(r.fecha_inicio) AS mes_nombre
    FROM reserva r
    WHERE MONTHNAME(r.fecha_inicio) = mes
    GROUP BY MONTHNAME(r.fecha_inicio);

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cliente_mes;
  -- Mete todos los datos que encuentre en la tabla creada
  read_loop: LOOP
    FETCH cliente_mes INTO total_personas, mes_nombre;
    IF done THEN
      INSERT INTO reserva_mes_especifico (numeros_reservas, nombre_mes)
      VALUES (total_personas, mes_nombre);
      LEAVE read_loop;
    END IF;
  END LOOP;

  CLOSE cliente_mes;
END
&&

DELIMITER ;

CALL mete_reserva_mes('May');

SELECT * FROM reserva_mes_especifico;


-- 4. Triggers

-- 4.1 te mete los clientes eliminados de la base de datos en una tabla nueva creada
create table if not exists baja_cliente(
	cod int not null,
	nombre varchar(100),
	apellido varchar(100),
	primary key(cod));


delimiter &&
DROP TRIGGER IF EXISTS trigger_before_delete_cliente&&

CREATE TRIGGER trigger_before_delete_cliente
before delete ON cliente FOR EACH ROW

BEGIN

  insert into baja_cliente values(old.codigo_cliente,old.nombre,old.apellido);

end &&

DELIMITER ;

-- 4.2 actualiza la fecha del pago a la fecha actual en reservas hechas

DROP TRIGGER IF EXISTS trigger_before_insert_reserva;

delimiter &&

CREATE TRIGGER trigger_before_insert_reserva
before insert ON reserva FOR EACH ROW
begin
	if(new.fecha_inicio <> now()) then
    set new.fecha_inicio = now();
   end if;
end 
&&

DELIMITER ;
