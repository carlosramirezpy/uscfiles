--USE uninorte;

ALTER PROCEDURE uninorte.pr_generar_pre_op_rrhh( 	@proceso 		integer,
													@forma_pago 	char(1),
													@cuenta_banco 	integer,
													@fecha_op 		date ) 
begin 
	declare @persona 			integer;
	declare @planilla 			integer;
	declare @sede 				char(3);
	declare @nombre_operativo 	varchar(250);
	declare @concepto_orden 	integer;
	declare @concepto_factura 	integer;
	declare @importe 			numeric(17,2);
	declare @montodescuentos 	numeric(17,2);
	declare @montodescuentosvalores 	numeric(17,2);
	declare @total 				numeric(17,2);
	declare @orden 				integer;
	declare @proceso_nombre 	varchar(40);
	declare @item 				integer;
	declare @tipo_proceso 		integer;
	declare @empresa 			integer;
	declare @moneda 			char(2);
	declare @factor_cambio 		numeric(17,2);
	declare @comentario 		varchar(120);
	declare @fecha 				date;
	declare @fecha_proceso 		date;
	declare @anio 				numeric(4);
	declare @mes 				numeric(2);
    declare @moneda_pago    	char(2);
    declare @persona_cabecera 	integer;
    declare @genera_factura		CHAR(1);
    DECLARE @FormaPagoDcto		CHAR(1);
	PRINT 'BEGIN uninorte.pr_generar_pre_op_rrhh';

	SELECT 	nombre,
			tipo_proceso,
			anio,
			mes 
	INTO 	@proceso_nombre,
			@tipo_proceso,
			@anio,
			@mes 
	FROM 	pxy_procesos_sueldos 
	WHERE 	proceso = @proceso;

 -- set @moneda = 'GS';
  set @empresa 			= 1;
  set @factor_cambio 	= 1;
  SET @FormaPagoDcto	= 'X'; --debito por descuentos.
  set @comentario 		= 'Generación Automática - Proc. ' || @proceso || ' - ' || @proceso_nombre;
  set @fecha_proceso 	= dateadd(dd,-1,dateadd(mm,1,ymd(@anio,@mes,1)));

  /*
  * -------------------------
  * tipo_proceso	nombre
  * -------------------------
	1	ANTICIPO DE SALARIOS
	2	PAGO SALARIOS ADMINISTRATIVOS
	3	PAGO HONORARIOS PROFESORES
	4	AGUINALDO
	5	LIQUIDACION
	-------------------------
  */
  
	if @tipo_proceso <> 4
	then 
		/* *******************************
		* 	CHEQUE
		*	****************************** */ 
		if @forma_pago = 'C'
		then 
			for cr_ordenes_temporal_ch as cr_ordenes_temporal_ch dynamic scroll cursor for 
			select 	persona,
					planilla,
					sede,
					nombre_operativo,
					concepto_orden,
					concepto_factura,
					fecha,
					sum(importe) as importe ,
					SUM(isnull(montodescuentos,0)) AS montodescuentos,
					moneda
			from 	pxy_ordenes_temporal 
			where 	proceso 	= @proceso 
			and 	forma_de_pago 	= @forma_pago 
			and 	cuenta_banco 	= @cuenta_banco 
			group by persona,
					planilla,
					sede,
					nombre_operativo,
					concepto_orden,
					concepto_factura,
					fecha,
					moneda 
			order by 	sede asc,
						nombre_operativo asc 
			
			DO 
				set @persona 	= persona;
				set @planilla 	= planilla;
				set @sede 		= sede;
				set @nombre_operativo 	= nombre_operativo;
				set @concepto_orden 	= concepto_orden;
				SET @concepto_factura	= concepto_factura;
				set @fecha 		= fecha;
				set @importe 	= importe;
				set @montodescuentos = montodescuentos;
				set @item 		= 1;
				set @total 		= importe;
				set @moneda 	= moneda;

				select fn_actualizar_numero_orden() into @orden from dummy;

				if @planilla in( 3,4,5 ) 
				then 
					set @total = 0 
				end if;
				
				insert into pre_ordenes( orden,
										tipoorden,
										fecha,
										persona,
										concepto_orden,
										total_a_pagar,
										moneda_factura,
										total_pago,
										moneda_pago,
										cambio,
										comentario,
										sede,
										proceso_sueldo,
										empresa ) 
								values( @orden,
										4, 
										@fecha_op,
										@persona,
										@concepto_orden,
										@total,
										@moneda,
										@importe,
										@moneda,
										@factor_cambio,
										@comentario,
										@sede,
										@proceso,
										@empresa ) ;
				
				if @@error <> 0 
				then 
					rollback work;
					raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
					return 
				end if;
				
				insert into pre_ordenes_valores( orden,
												item,
												forma_pago,
												monto_pago,
												cuenta_movto,
												docto_fecha,
												docto_nro,
												beneficiario,
												comentario 
												) 
										values( @orden,
												@item,
												@forma_pago,
												@importe,
												@cuenta_banco,
												@fecha_op,
												@persona, --anterior era null, solo a modo de informacion.
												@nombre_operativo,
												@comentario 
										);
				
				if @@error <> 0 
				then 
					rollback work;
					raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
					return 
				end if;
				
				IF @montodescuentos>0 
				THEN 
					insert into pre_ordenes_valores( orden,item,forma_pago,monto_pago,cuenta_movto,docto_fecha,docto_nro,beneficiario,comentario ) 
					values( @orden,@item+1,@FormaPagoDcto,@montodescuentos,null,@fecha_op,@persona,@nombre_operativo,'Descuento Generados - RRHH' ) ;
					if @@error <> 0 
					then 
						rollback work;
						raiserror 99999 '<*Error al insertar en Ordenes. [NotaDebito]Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
						return ;
					end if;
				END IF; 
								
				/*if @planilla in( 3,4 ) anterior...CR
				* then 
				* no importa mas este control, dentro del SP
				* resuelve si genera o no factura, se encuentra en pxy_tipos_procesos_planillas
				* */
					call pr_generar_pre_factura_rrhh(@proceso,
													@persona,
													@comentario,
													@moneda,
													@sede,
													@importe,
													@orden,
													@fecha_proceso,
													@planilla,
													@montodescuentos);
					if @@error <> 0 
					then 
						return 
					end if 
				/*end if
				*/ 
			end for --end DO
		end if; --tipoPAGO
		
		/* *******************************
		* 	DEBITO
		*	*******************************  
		*/
		IF @forma_pago = 'D' 
		THEN  
			SET  	@persona 	= null;
			SET 	@importe 	= 0;
			SET 	@total 		= 0 ;
			SET 	@montodescuentos = 0 ;
			
			select 	convert(integer,valor_numero) 
			into 	@persona_cabecera
			from 	uninorte.parametros_adicionales 
			where 	nombre = 'PERSONA_USC';
			
			if isnull(@persona_cabecera,0) = 0 
			then 
				rollback work;
				raiserror 99999 '<*[pre]Debe ingresar el código de persona para USC en la tabla parametros_adicionales*>';
				return 
			end if;
			
			for cr_sedes as cr_sedes dynamic scroll cursor for 
			select 	sede,
					concepto_orden,
					fecha,
					sum(importe) as total 
					,SUM(isnull(montodescuentos,0)) AS montodescuentos
					,moneda 
			from 	pxy_ordenes_temporal 
			where 	proceso 		= @proceso 
			and 	forma_de_pago 	= @forma_pago 
			and 	cuenta_banco 	= @cuenta_banco 
			and 	planilla not in( 3,4,5 ) 
			group by 	sede,
						concepto_orden,
						fecha , 
						moneda 
			order by sede asc 
			DO 
				set @sede 	= sede;
				set @concepto_orden = concepto_orden;
				set @fecha 	= fecha;
				set @total 	= total;
				SET @montodescuentos=montodescuentos;
				set @item 	= 0;
				
                set @nombre_operativo = fn_nombre_empresa(@persona);
                set @moneda 		= moneda;
				set @moneda_pago 	= moneda;
                
				message '@sede = '+string(@sede) type info to client;
				message '@concepto_orden = '+string(@concepto_orden) type info to client; 	
				message '@total = '+string(@total) type info to client;
				message '@moneda = '+string(@moneda) type info to client; 	

				select fn_actualizar_numero_orden() into @orden from dummy;

				PRINT 'cr_sedes';
				PRINT '@sede = %1!', @sede;
				PRINT '@concepto_orden = %1!', @concepto_orden; 	
				PRINT '@total = %1!', @total;
				PRINT '@moneda = %1!', @moneda; 	
				PRINT 'sede=%5!, orden=%1!, persona_cabecera=%2!, importe=%3!, total=%4!', @orden, @persona_cabecera, @importe, @total, @sede;
				
				insert into pre_ordenes( orden,
										tipoorden,
										fecha,
										persona,
										concepto_orden,
										total_a_pagar,		--AQUI va el MontoNeto o Monto sin descuentos
										moneda_factura,
										total_pago,
										moneda_pago,
										cambio,
										comentario,
										sede,
										proceso_sueldo,
										empresa 
										) 
								values( @orden,
										4, --2, 
										@fecha_op,
										@persona_cabecera,
										@concepto_orden,
										(abs(isnull(@total,0)) + abs(ISNULL(@montodescuentos,0))), --anterior isnull(@total,0),	--AQUI va el MontoNeto o Monto sin descuentos
										@moneda,
										isnull(@total,0), --isnull(@importe,0),
										@moneda_pago,
										@factor_cambio,
										@comentario,
										@sede,
										@proceso,
										@empresa 
									);
				if @@error <> 0 
				then 
					rollback work;
					raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
					return 
				end if;
				
				for cr_ordenes_temporal_db as cr_ordenes_temporal_db dynamic scroll cursor for 
				select 	persona,
						planilla,
						nombre_operativo,
						sum(importe) as importe,
						SUM(ISNULL(montodescuentos,0)) AS montodescuentosval
				from 	pxy_ordenes_temporal 
				where 	proceso 		= @proceso 
				and 	forma_de_pago 	= @forma_pago 
				and 	cuenta_banco 	= @cuenta_banco 
				and 	sede 			= @sede 
				and 	planilla not in( 3,4,5 ) 
				group by persona,planilla,nombre_operativo
				order by nombre_operativo asc 
				
				DO
					set @persona 	= persona;
					set @planilla 	= planilla;
					set @nombre_operativo = nombre_operativo;
					set @importe 	= importe;
					SET @montodescuentosvalores = montodescuentosval;
					set @item 		= @item+1;
					-- set @moneda_pago     = moneda;
				
					message '@persona = '+string(@persona) type info to client;
					message '@planilla = '+string(@planilla) type info to client; 	
					message '@nombre_operativo = '+string(@nombre_operativo) type info to client;
					message '@moneda = '+string(@moneda) type info to client;
					
					PRINT 'cr_ordenes_temporal_db';
					PRINT '@persona = %1!', @persona;
					PRINT '@planilla = %1!', @planilla; 	
					PRINT '@nombre_operativo = %1!', @nombre_operativo;
					PRINT '@moneda = %1!', @moneda;
					 
					insert into pre_ordenes_valores( orden,
													item,
													forma_pago,
													monto_pago,
													cuenta_movto,
													docto_fecha,
													docto_nro,
													beneficiario,
													comentario 
													) 
											values( @orden,
													@item,
													@forma_pago,
													@importe,
													@cuenta_banco,
													@fecha_op,
													null,
													@nombre_operativo,
													@comentario 
													);
					
					if @@error <> 0 
					then 
						rollback work;
						raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
						return 
					end if ;

					IF @montodescuentosvalores>0
					THEN 
						SET @item= @item +1;
						insert into pre_ordenes_valores( orden,item,forma_pago,monto_pago,cuenta_movto,docto_fecha,docto_nro,beneficiario,comentario ) 
						values( @orden,@item,@FormaPagoDcto,
								@montodescuentosvalores, --@montodescuentos,
								null,@fecha_op,@persona,@nombre_operativo,'Descuento Generados - RRHH' ) ;
						if @@error <> 0 
						then 
							rollback work;
							raiserror 99999 '<*Error al insertar en Ordenes. [NotaDebito]Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
							return ;
						end if;
					END IF ; 
					
				end for ;
			end for;
			
			for cr_sedes_honorarios as cr_sedes_honorarios dynamic scroll cursor for 
			select 	persona,
					planilla,
					sede,
					nombre_operativo,
					concepto_orden,
					fecha,
					sum(isnull(importe,0)) as importe, 
					sum(isnull(montodescuentos,0)) AS montodescuentosval,
					moneda 
			from 	pxy_ordenes_temporal 
			where 	proceso 		= @proceso 
			and 	forma_de_pago 	= @forma_pago 
			and 	cuenta_banco 	= @cuenta_banco 
			and 	planilla in( 3,4,5 ) 
			group by persona,
					planilla,
					sede,
					nombre_operativo,
					concepto_orden,
					fecha , 
					moneda 
			order by sede asc,
					nombre_operativo asc 
			
			DO
				set @persona 			= persona;
				set @planilla 			= planilla;
				set @sede 				= sede;
				set @nombre_operativo 	= nombre_operativo;
				set @concepto_orden 	= concepto_orden;
				set @fecha 				= fecha;
				set @importe 			= importe;
				SET @montodescuentosvalores 	= montodescuentosval;
				set @item 		= 1;
				set @total 		= 0;
				select fn_actualizar_numero_orden() into @orden from dummy;
                set @moneda     = moneda;
				
				insert into pre_ordenes( orden,
										tipoorden,
										fecha,
										persona,
										concepto_orden,
										total_a_pagar,	--AQUI va el MontoNeto o Monto sin descuentos
										moneda_factura,
										total_pago,
										moneda_pago,
										cambio,
										comentario,
										sede,
										proceso_sueldo,
										empresa 
										) 
								values( @orden,
										4, --1, 
										@fecha_op,
										@persona,
										@concepto_orden,
										@total, --AQUI va el MontoNeto o Monto sin descuentos
										@moneda,
										@importe,
										@moneda,
										@factor_cambio,
										@comentario,
										@sede,
										@proceso,
										@empresa 
									) ;

				if @@error <> 0 
				then 
					rollback work;
					raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
					return 
				end if;
				
				insert into pre_ordenes_valores( orden,
												item,
												forma_pago,
												monto_pago,
												cuenta_movto,
												docto_fecha,
												docto_nro,
												beneficiario,
												comentario 
												) 	
										values( @orden,
												@item,
												@forma_pago,
												@importe,
												@cuenta_banco,
												@fecha_op,
												null,
												@nombre_operativo,
												@comentario 
										) ;
				
				if @@error <> 0 
				then 
					rollback work;
					raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
					return 
				end if;
				
				IF @montodescuentosvalores>0
				THEN 
					insert into pre_ordenes_valores( orden,
													item,
													forma_pago,
													monto_pago,
													cuenta_movto,
													docto_fecha,
													docto_nro,
													beneficiario,
													comentario 
													) 	
											values( @orden,
													@item + 1,
													@FormaPagoDcto, --DEBITO
													@montodescuentosvalores, --@montodescuentos,
													null,
													@fecha_op,
													null,
													@nombre_operativo,
													'Descuento Generados - RRHH' 
											) ;
											if @@error <> 0 
											then 
												rollback work;
												raiserror 99999 '<*Error al insertar en Ordenes. [NotaDebito]Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
												return 
											end if;
				END IF ; 
				
				call pr_generar_pre_factura_rrhh(@proceso,
												@persona,
												@comentario,
												@moneda,
												@sede,
												@importe,
												@orden,
												@fecha_proceso, 
												@planilla,
												@montodescuentosvalores --@montodescuentos
				);
				if @@error <> 0 
				then 
					RETURN; 
				end if ;
			end for ;
		end IF;
		/*	
		* 	*******************************
		* 	TIPO DE PAGO DIFF a C y D
		* 	*******************************		    
		*/
		ELSE 
			set @persona = null;
			select valor_numero into @persona from parametros_adicionales where nombre = 'PERSONA_USC';
			if isnull(@persona,0) = 0 
			then 
				rollback work;
				raiserror 99999 '<*Debe ingresar el código de persona para USC en la tabla parametros_adicionales*>';
				return 
			end if;
			
			set @nombre_operativo = fn_nombre_empresa(@persona);
			
			for cr_sedes_db as cr_sedes_db dynamic scroll cursor for 
			select 	sede,
					concepto_orden,
					fecha,
					sum(importe) as total ,
					sum(isnull(montodescuentos,0)) AS montodescuentosval,
					moneda
			from 	pxy_ordenes_temporal 
			where 	proceso = @proceso 
			and 	forma_de_pago = @forma_pago 
			group by sede,concepto_orden,fecha , moneda 
			order by sede asc 
			
			do 	set @sede 			= sede;
				set @concepto_orden = concepto_orden;
				set @fecha 			= fecha;
				set @total 			= total;
				SET @montodescuentosvalores 	= montodescuentosval;
				set @item 			= 1;
				select fn_actualizar_numero_orden() into @orden from dummy;
                set  @moneda = moneda;

				insert into pre_ordenes( orden,
										tipoorden,
										fecha,
										persona,
										concepto_orden,
										total_a_pagar,	--AQUI va el MontoNeto o Monto sin descuentos
										moneda_factura,
										total_pago,
										moneda_pago,
										cambio,
										comentario,
										sede,
										proceso_sueldo,
										empresa ) 
								values( @orden,
										4, --2,
										@fecha_op,
										@persona,
										@concepto_orden,
										@total,		--AQUI va el MontoNeto o Monto sin descuentos
										@moneda,
										@total,
										@moneda,
										@factor_cambio,
										@comentario,
										@sede,
										@proceso,
										@empresa ) ;
				
				if @@error <> 0 
				then 
					rollback work;
					raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
					return 
				end if;
				
				insert into pre_ordenes_valores( orden,item,forma_pago,monto_pago,cuenta_movto,docto_fecha,docto_nro,beneficiario,comentario ) 
				values( @orden,@item,@forma_pago,@total,@cuenta_banco,@fecha_op,@persona,@nombre_operativo,@comentario ) ;
			  
				if @@error <> 0 
				then 
					rollback work;
					raiserror 99999 '<*Error al insertar en Ordenes. Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
					return ;
				end if ;
				IF @montodescuentosvalores>0
				THEN 
					insert into pre_ordenes_valores( orden,item,forma_pago,monto_pago,cuenta_movto,docto_fecha,docto_nro,beneficiario,comentario ) 
					values( @orden,@item+1,@FormaPagoDcto,@montodescuentosvalores,null,@fecha_op,@persona,@nombre_operativo,'Descuento Generados - RRHH') ;
					if @@error <> 0 
					then 
						rollback work;
						raiserror 99999 '<*Error al insertar en Ordenes. [NotaDebito]Proceso Sueldo: ' || @proceso || ', Forma Pago: ' || @forma_pago || ', Persona: ' || @persona || ', Sede: ' || @sede || '*>';
						return 
					end if;
				END IF ; 
				
				
				
			end for 
		end if;
		
		if isnull(@orden,0) = 0 
		then 
			rollback work;
			raiserror 99999 '<*No existen datos para generar una Orden de Pago para los parámetros ingresados*>';
			return 
		end if
END
