--USE usc_rrhh;

ALTER PROCEDURE uninorte.pr_generar_orden_temporal( @proceso	integer,  														 
                                                        @planilla	integer,
                                                        @moneda 	CHAR(2)
)    
begin  
declare @persona				T_persona				   ;  
declare @persona_academico		T_persona				   ;  
declare @legajo				 	T_persona				   ;  
declare @ingresos				T_dinero				   ;  
declare @egresos				T_dinero				   ;  
declare @ingresos_planilla		T_dinero				   ;  
declare @egresos_planilla 		T_dinero				   ;  
declare @total					T_dinero				   ;  
declare @total_planilla		  	T_dinero				   ;  
declare @nombre_persona			T_descripcion120	 ;  
declare @ClaseProceso					T_clase_proceso		 ;  

declare @concepto_orden			T_concepto_orden	 ;  
declare @concepto_factura		T_concepto_orden	 ;  

declare @centro_de_costo		T_centro_costo		 ;  
declare @sede					T_centro_costo		 ;  
declare @forma_de_pago			T_forma_de_pago		 ;  
declare @numero_cuenta			T_documento_fisico ;  
declare @TipoProceso			numeric(2)				 ;  
declare @monto_minimo_debito	T_dinero				   ;  
declare @cuenta_banco			T_banco					   ;    
declare @countPersonas			integer;
declare @countCuenta			integer;
DECLARE @smserror				VARCHAR(2000);

declare err_notfound exception for sqlstate '02000'  ;   
 
declare csr_orden_temporal cursor for   
	select 	distinct personas.persona, 
			nombre_operativo, 
			legajo, 
			centro_de_costo  
	from    novedades_proceso, 
			personas   
	where   novedades_proceso.persona = personas.persona  and
			proceso  = @proceso  AND
			planilla = @planilla AND
			(SELECT COUNT(*) FROM sueldos s 
			 WHERE s.persona = personas.persona 
			 AND s.planilla = @planilla 
			 AND s.moneda = @moneda) >= 1;    
			 

	PRINT 'BEGIN uninorte.pr_generar_orden_temporal';

	/*BORRAMOS LO QUE EXISTE..*/
	delete 	from 	ordenes_temporal  	
	where 	proceso   	= @proceso  				  
	and 	planilla   	= @planilla
	AND		moneda		= @moneda;

	select 	tp.clase,
			tp.tipo_proceso  
	into   	@ClaseProceso, 
			@TipoProceso  
	from   	tipos_procesos		tp, 
			procesos_sueldos	ps
	where  	tp.tipo_proceso = ps.tipo_proceso  
	and		proceso = @proceso;                                                                                                                                                                                                  
        
	/*debe reemplazarse..
	SELECT  concepto_op    	
	INTO	@concepto_orden      
	FROM    tipos_procesos       
	WHERE   tipo_proceso = @TipoProceso;
	*/
	/* reemplazado..tabla nueva; 17.08.2015 CR*/
	SELECT 	tpp.concepto_orden,
			tpp.concepto_factura
	INTO 	@concepto_orden,
			@concepto_factura
	FROM 	tipos_procesos_planillas tpp
	WHERE 	tpp.tipo_proceso=@TipoProceso 
	AND 	tpp.planilla = @planilla;

	IF @concepto_orden IS NULL OR @concepto_orden=0
	THEN 
		set @smserror = 'ERROR, no existe @concepto_orden para la planilla [' || CONVERT(VARCHAR(10), @planilla) ||'] del Tipo de Proceso [' || CONVERT(VARCHAR(10), @TipoProceso ) || '] Configurar en Menu: Datos Basicos> Tipos de Procesos.';
		PRINT @smserror;
		rollback work;
		RAISERROR 99999 @smserror ;
		RETURN 
	END IF; 
    open csr_orden_temporal;    
    LoopCursor:  loop    	fetch next csr_orden_temporal  	
							into 	@persona, 
									@nombre_persona,
									@legajo, 
									@centro_de_costo;    	
    
      

    	IF sqlstate = err_notfound THEN  		
		leave LoopCursor;  	
		END IF;  	  	                                                                                                                 		                                 		
				
		IF @ClaseProceso='P' 
		THEN 	/* nuevo para distinguir pago a profesores de empleados ttorales 01/07/2015 */
			PRINT '@ClaseProceso %1! %2!', @ClaseProceso, @legajo;
			SELECT 	count(*) 
			INTO 	@countPersonas
			FROM 	proxy_profesores 
			WHERE 	legajo = @legajo;

			IF @countPersonas>1  
			THEN
				rollback work;
				raiserror 99999 '<**Legajo posee mas de una persona '||convert(varchar(10),@legajo,103)||'*>';
				return ;
			END IF;

			IF @countPersonas=0 or @countPersonas is null
			THEN
				rollback work;
				raiserror 99999 '<*Debe asignar el legajo en el modulo academico '||convert(varchar(10),@legajo,103)||'*>';
				return ;
			END IF;


			SELECT 	persona    			
			INTO   	@persona_academico  			
			FROM 	proxy_profesores    			
			WHERE 	legajo = @legajo;  

		ELSEIF @ClaseProceso = 'E' 
		THEN 	/// nuevo para distinguir pago a profesores de empleados ttorales 01/07/2015
			PRINT '@ClaseProceso %1! %2!', @ClaseProceso, @legajo;
			
			/* desde aqui nuevo ttorales 01/07/2015*/
			SELECT 	count(*) 
			INTO 	@countPersonas
			FROM 	proxy_funcionarios 
			WHERE 	legajo = @legajo;

			IF @countPersonas>1  
			THEN
				rollback work;
				raiserror 99999 '<**Legajo posee mas de una persona '||convert(varchar(10),@legajo,103)||'*>';
				return ;
			END IF;

			IF @countPersonas=0 or @countPersonas is null
			THEN
				rollback work;
				raiserror 99999 '<*Debe asignar el legajo en el modulo academico '||convert(varchar(10),@legajo,103)||'*>';
				return ;
			END IF;


			SELECT 	persona    			
			INTO   	@persona_academico  			
			FROM 	proxy_funcionarios   			
			WHERE 	legajo = @legajo; 
			/* hasta aqui nuevo ttorales 01/07/2015*/
		END IF;

		select 	sum(round(cantidad * base * factor,0))  
		into 	@ingresos  		  
		from 	novedades_proceso, novedades  		 
		where   novedades.novedad   = novedades_proceso.novedad  	and 
				proceso             = @proceso  			        and 
				persona             = @persona  			        and 
				centro_de_costo     = @centro_de_costo  			and 
				novedades.ingreso   = 'S'; 
		
		select sum(round(cantidad * base * factor,0))  		  
		into @egresos  		  
		from novedades_proceso, novedades  		 
		where novedades.novedad     = novedades_proceso.novedad  	and 
		proceso                     = @proceso  			        and 
		persona                     = @persona  			        and 
		centro_de_costo             = @centro_de_costo  			and 
		novedades.ingreso           = 'N';              	                                                                                                             			                                            			
	
		select sum(round(cantidad * base * factor,0))  			  
		into @ingresos_planilla  			  
		from novedades_proceso, novedades  			 
		where novedades.novedad     = novedades_proceso.novedad  	and 
		proceso                     = @proceso  				    and 
		persona                     = @persona  				    and 
		centro_de_costo             = @centro_de_costo  			and 
		planilla                    = @planilla  				    and 
		novedades.ingreso           = 'S';             		  			                                           			
	
		select  sum(round(cantidad * base * factor,0))  			  
		into    @egresos_planilla  			  
		from    novedades_proceso, novedades  			 
		where   novedades.novedad   = novedades_proceso.novedad  	and 
				proceso             = @proceso  				    and 
				persona             = @persona  				    and 
				centro_de_costo     = @centro_de_costo  			and 
				planilla            = @planilla  				    and 
				novedades.ingreso   = 'N';                	                             	
		
		set @total = isnull(@ingresos,0) - isnull(@egresos,0);  	                                                                                      	
		set @total_planilla = isnull(@ingresos_planilla,0) - isnull(@egresos_planilla,0); 
	
		message(string('persona_rrhh: ',string(@persona))) type info to client;      
		message(string('total_planilla: ',string(@total_planilla))) type info to client;
	  
		IF @total < 0 THEN  		
			raiserror 99999 'El legajo %1! tiene monto neto negativo Monto: %2! ',@legajo,@total;   		
			return;  	
		END IF;    	                 	
			
		IF @total > 0 
		THEN    			                                                                         			
			IF @TipoProceso in (1,2,3,4)
			THEN  // tipos de proceso: pago salario adm, pago honorarios profesores, aguinaldo
				/*
				* tipo_proceso	nombre
					1	ANTICIPO DE SALARIOS
					2	PAGO SALARIOS ADMINISTRATIVOS
					3	PAGO HONORARIOS PROFESORES
					4	AGUINALDO
				*/
				IF @ClaseProceso = 'E' 
				THEN   // Clase E - empleado                						
					IF exists (select 1 from   cargos_unidades  												  
								where  persona = @persona  	and    
								tipo_empleado in ('E','O')  and   // tipo de empleado administrativo, operativo
								length(numero_cuenta) > 2   and    
								estado = 'A'  				and	 
								banco > 0) 
					THEN  	
						/*TIENE CUENTA ASIGNADA, ENTONCES ES DEBITO:D*/
						set @forma_de_pago = 'D';  // forma de pago debito									
					
						select  min(banco)   									
						into 	@cuenta_banco  									
						from    cargos_unidades  								  
						where   persona                 = @persona  		and    
								tipo_empleado           in ('E','O')  		and   // tipo de empleado administrativo, operativo 
								length(numero_cuenta)   > 2   				and    
								estado                  = 'A'  				and	 
								banco > 0;  						
					ELSE  							
						/*<<NO>>TIENE CUENTA ASIGNADA, ENTONCES ES CHEQUE:C*/
						set @forma_de_pago = 'C';
						//raiserror 99999 'El legajo %1! no tiene asignado un cargo, verifique! ',@legajo;   	comentado ttorales 01/07/2015	
						//   return;  		
				
						/*ttorales 01/07/2015*/
						select  min(banco)   									
						into   	@cuenta_banco  									
						from   	cargos_unidades  								  
						where  	persona	= @persona  		 
						and		estado	= 'A'  	       
						and		tipo_empleado in ('E','O') 
						and     centro_de_costo         = @centro_de_costo ;
						// tipo  de empleado administrativo, operativo 
								 
						SELECT 	count(*) 
						INTO 	@countCuenta
						FROM 	cargos_unidades 
						where  persona	= @persona  		 
						and	estado		= 'A'  	       
						and	tipo_empleado	in ('E','O') 
						and	centro_de_costo	= @centro_de_costo ;  
							
						IF @countCuenta=0 or @countCuenta is null
						THEN
						  message(string('countCuenta: ',string(@countCuenta))) type info to client;   
							rollback work;
							raiserror 99999 '<*Debe asignar una cuenta bancaria al legajo con nº: '||convert(varchar(10),@legajo,103)||' para el centro de costos: '||convert(varchar(10),@centro_de_costo,103)||'*>';
							return ;
						END IF;  
						/*hasta aqui ttorales 01/07/2015*/
					END IF;  					
				ELSE 
				/*nuevo ttorales 09/07/2015*/
				/* NO EMPLEADO<>E :: PROFESOR */
					IF exists (select 1 from   cargos_unidades  												  
								where  persona = @persona  	and    
								tipo_empleado ='P'  		and   // tipo de DOCENTE
								length(numero_cuenta) > 2   and    
								estado = 'A'  				and	 
								banco > 0) 
					THEN  	
						/*TIENE CUENTA ASIGNADA, ENTONCES ES DEBITO:D*/
						set @forma_de_pago = 'D';  // forma de pago debito									
					
						select  min(banco)   									
						into 	@cuenta_banco  									
						from    cargos_unidades  								  
						where   persona                 = @persona  and    
								tipo_empleado           ='P'  		and   // tipo de DOCENTE 
								length(numero_cuenta)   > 2   		and    
								estado                  = 'A'  		and	 
								banco > 0;  						

					ELSE  						
						/*hasta aqui ttorales 09/07/2015*/
						/*<<NO>>TIENE CUENTA ASIGNADA, ENTONCES ES CHEQUE:C*/
						set @forma_de_pago = 'C';  
						  
						select  min(banco)   									
						into   @cuenta_banco  									
						from   cargos_unidades  								  
						where persona                 = @persona  	AND     
							  estado                  = 'A'  	  	AND  
							  tipo_empleado           = 'P' 		AND           // tipo empleado P Profesor
							  centro_de_costo         = @centro_de_costo ; 
								 
						SELECT 	count(*) 
						INTO 	@countCuenta
						FROM 	cargos_unidades 
						where  persona                 = @persona	and    
							   estado                  = 'A'  	    and 
							   tipo_empleado           = 'P' 		and
							   centro_de_costo         = @centro_de_costo ;  
	  
						IF @countCuenta=0 or @countCuenta is null
						THEN
							message(string('countCuenta: ',string(@countCuenta))) type info to client;   
							rollback work;
							raiserror 99999 '<*Debe asignar una cuenta bancaria al legajo con nº: '||convert(varchar(10),@legajo,103)||' para el centro de costos: '||convert(varchar(10),@centro_de_costo,103)||'*>';
							return ;
						END IF;       
					END IF;     					
				END IF;  				                                                               			
			ELSE  
				/*CR
				* TODOS LOS PROCESOS DIFF(2,3,4)
				*	5	LIQUIDACION
				*/
				set @forma_de_pago = 'C';  			
			END IF;   

			SELECT 	sede    			 
			INTO 	@sede  			    
			FROM 	centros_de_costos    			 
			WHERE 	centro_de_costo= @centro_de_costo;  			  			
		
					
			message(string('persona_acad: ',string(@persona_academico))) type info to client;   
			message(string('sede: ',string(@sede))) type info to client;  
			message(string('total_planilla: ',string(@total_planilla))) type info to client;      
			message(string('concepto_orden: ',string(@concepto_orden))) type info to client;  
			message(string('forma_de_pago: ',string(@forma_de_pago))) type info to client;  

			select fn_nombre_persona_orden(@persona) 
			into @nombre_persona
			from dummy;
			
			print '@proceso %1!', @proceso;
			print '@persona_academico %1!',@persona_academico;  
			print '@legajo %1!',		@legajo				 ;
			print '@planilla %1!',@planilla  					;	 
			print '@sede %1!', @sede   						 ;
			print '@total_planilla %1!', @total_planilla;
			print '@egresos_planilla %1!',	@egresos_planilla;					 
			print '@nombre_persona %1!',  		@nombre_persona;				 
			print '@concepto_orden %1!', @concepto_orden;
			print '@concepto_factura %1!',  @concepto_factura;						 
			print '@forma_de_pago %1!',@forma_de_pago;
			print '@cuenta_banco %1!',@cuenta_banco;
			print '@moneda %1!',@moneda;

			insert into ordenes_temporal(   proceso,     								
											persona,   								
											legajo,
											planilla,					  								
											sede,    								
											fecha,     								
											importe,
											montodescuentos,     								
											nombre_operativo,     								
											concepto_orden, 
											concepto_factura,     								    								
											forma_de_pago,
											cuenta_banco,
											moneda)  				
									values( @proceso,  						 
											@persona_academico,  
											@legajo,						 
											@planilla,  						 
											@sede,  						 
											current date,  						 
											@total_planilla,
											isnull(@egresos_planilla,0),  						 
											@nombre_persona,  						 
											@concepto_orden,
											@concepto_factura,  						 
											@forma_de_pago,
											@cuenta_banco,
											@moneda);               	
	
		END IF;	  
		set @persona		=null;
		set @nombre_persona	=null;
		set @legajo			=null;
		set @centro_de_costo=null;
		set @countPersonas	=null;
	end Loop LoopCursor;    
	close csr_orden_temporal;  
	deallocate cursor csr_orden_temporal;
	PRINT 'END uninorte.pr_generar_orden_temporal';
	    
END