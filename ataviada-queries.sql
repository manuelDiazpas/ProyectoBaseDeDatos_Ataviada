use ataviada;

-- 1. Consultas

-- Obtener el identificador de los clientes que han comprado algún producto
-- que no tenga una direccion

select c.CLIENTE_codigo_cliente from clientehacepedido c 
where c.CLIENTE_codigo_cliente  in (select c2.codigo_cliente from cliente c2 
where c2.direccion is null);


-- ordenar los productos del más caro al más barato que sea menor de 1000€ y mayor de 500€
select p.nombre_producto, concat(p.precio, '€')  from modo_pago mp 
inner join producto p on p.MODO_PAGO_codigo_cuenta = mp.codigo_cuenta 
where p.precio between 500 and 1000
order by p.precio desc; 

-- nombre de 5 productos reservados que valgan menos de 10€, ademas de la cantidad reservada
select p.nombre_producto, concat(pr.precio, '€'), pr.cantidad  from productoaparecereserva pr 
inner join producto p ON pr.PRODUCTO_cod_producto = p.cod_producto
where pr.precio <10
limit 5

-- productos que esten en stock agrupadas en tallas
select s.talla, count(s.PRODUCTO_cod_producto) from stock s 
inner join producto p ON s.PRODUCTO_cod_producto = p.cod_producto
group by s.talla;

-- nombre de cliente que alquila producto + la fecha que se alquiló
select c.nombre, a.fecha_alquiler, p.nombre_producto from alquila a 
inner join cliente c ON c.codigo_cliente = a.CLIENTE_codigo_cliente 
inner join producto p ON a.PRODUCTO_cod_producto = p.cod_producto ;


-- 2. Vistas

create or replace view tallas_productos_stock
as select s.talla, count(s.PRODUCTO_cod_producto) from stock s 
inner join producto p ON s.PRODUCTO_cod_producto = p.cod_producto
group by s.talla;

create or replace view clientes_sin_direccion
as select c.CLIENTE_codigo_cliente from clientehacepedido c 
where c.CLIENTE_codigo_cliente  in (select c2.codigo_cliente from cliente c2 
where c2.direccion is null);

-- 3. Funciones y Procedimientos

-- 3.1 Funciones

-- Funcion que te suma el precio total de dos productos en stock

drop function suma;

delimiter &&
create Function Suma(p1 int, p2 int)
returns double
deterministic
begin
	
	declare pr1 double;
	declare pr2 double;

	select l.precio into pr1 from lineapedido l 
	where l.PRODUCTO_cod_producto = p1;
	
	select l.precio into pr2 from lineapedido l 
	where l.PRODUCTO_cod_producto = p2;
	
	
 Return (pr1 + pr2);
end
&&


delimiter ;
select suma(1, 100);

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
select buscar_nombre_cliente(1);

-- 3.2 Procedimientos

-- cuenta cuantos clientes empiezan con una letra

drop procedure total_cllientes_letra;

delimiter &&
CREATE PROCEDURE total_clientes_letra (IN palabra varchar(20))
BEGIN
  SELECT COUNT(*) FROM cliente c
  WHERE c.nombre like concat(palabra,'%');
END 
&&

delimiter ;
call total_clientes_letra('e');


-- devuelve el numero de pedidos y reservas realizados por el cliente

drop procedure reservas_pedidos_cliente;

delimiter &&
CREATE PROCEDURE reservas_pedidos_cliente(IN cod int)
BEGIN

	declare reserva int default(select count(c.CLIENTE_codigo_cliente) from clientehacereserva c 
	where c.CLIENTE_codigo_cliente = cod);
	
	declare pedido int default(select count(c.CLIENTE_codigo_cliente) from clientehacepedido c 
	where c.CLIENTE_codigo_cliente = cod);
	
	SELECT concat('El cliente ', buscar_nombre_cliente(cod), ' tiene ', (reserva + pedido), ' reservas y pedidos en total.') 
	FROM cliente c 
	limit 1;

END 
&&

delimiter ;
call reservas_pedidos_cliente(2);

-- inserta en una tabla llamada 'reservas_hechas_mes' donde almacena el numero de reservas hechas hoy


drop table if exists reserva_mas_reciente;
create table reserva_mas_reciente(
	numeros_reservas int,
	fecha_reciente_reserva datetime);


DROP PROCEDURE IF EXISTS mete_reserva_reciente;

DELIMITER &&
CREATE PROCEDURE mete_reserva_reciente()
BEGIN
  DECLARE done INT DEFAULT FALSE;
  
  declare a int;
  DECLARE cliente_mes CURSOR FOR SELECT c.CLIENTE_codigo_cliente FROM clientehacereserva c 
 						inner join reserva r ON c.RESERVA_numero_identificacion = r.numero_identificacion 
 						where month(r.fecha_inicio) = month(now());
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cliente_mes;

  read_loop: LOOP
    FETCH cliente_mes INTO a;
    IF done then
      INSERT INTO ataviada.reserva_mas_reciente VALUES (a, now());
      LEAVE read_loop;
    END IF;
  END LOOP;

  CLOSE cliente_mes;
END
&&

DELIMITER ;
CALL mete_reserva_reciente();

SELECT * FROM reserva_mas_reciente;

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
