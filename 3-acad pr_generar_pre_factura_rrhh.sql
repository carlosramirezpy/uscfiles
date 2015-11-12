--USE uninorte ;

ALTER PROCEDURE uninorte.pr_generar_pre_factura_rrhh ( @proceso				integer,  														 
													@persona			integer,  														 
													@comentario			varchar(120),  														 
													@moneda				char(2),  														 
													@sede				char(3),  														 
													@importe 			numeric(17,2),  														 
													@orden				integer,  														 
													@fecha_proceso		date,
													@planilla			integer,
													@montodescuentos	money	= NULL 
)  

begin    

declare @tipo_proceso			integer;  	
declare @factura				integer;  	
declare @forma_pago				char(1);  	
declare @factura_fisica			varchar(20);  	
declare @monto_gravado			numeric(17,2);  	
declare @monto_exento			numeric(17,2);  	
declare @monto_impuesto			numeric(17,2);  	
declare @saldo					numeric(17,2);  	
declare @tipo_de_factura		char(1);  	
declare @factor_cambio			numeric(17,2);  	
declare @monto_gravado5			numeric(17,2);   	
declare @monto_impuesto5		numeric(17,2);  	
declare @monto_total10			numeric(17,2);     	
declare @monto_total5			numeric(17,2);     	
declare @empresa				integer;  	
declare @item					integer;  	
declare @concepto				integer;  	
declare @porcentaje_impuesto	numeric(17,2);   	
declare @anio					numeric(4);  	
declare @mes					numeric(2);   	
declare @proveedor				integer;    	
declare @generar_factura		CHAR(1);      
DECLARE @sms					VARCHAR(1000);       
DECLARE @generaIVA				integer;          
declare	@ImporteFacturaTOT		MONEY;  
DECLARE @MontoGRAV				MONEY;
DECLARE @MontoIVA				MONEY;                 	

--return;

select 	tipo_proceso       
into 	@tipo_proceso  	  
from 	pxy_procesos_sueldos  	 
where 	proceso = @proceso;    	                           	

	
	--select 	isnull(max(factura),0) + 1  	  
	--into 	@factura  	  
	--from 	facturas_recibidas;   
	
	/* 
	* anterior... remplazado por el siguiente select CR
	* 
		select 	concepto_factura  	  
		into 	@concepto  	  
		from 	pxy_tipos_procesos  	 
		where 	tipo_proceso = @tipo_proceso;
	ESTE>*/
	
		SELECT 	isnull(concepto_factura,0),
				isnull(genera_factura,'N'),
				ISNULL(generaIVA, 0)	--porcentaje de impuesto a utilizar. si es mayor a 0 entonces significa que genera iva.RECALCULAR
		INTO 	@concepto,
				@generar_factura,
				@generaIVA
		FROM 	pxy_tipos_procesos_planillas ptpp
		where 	tipo_proceso 	= @tipo_proceso
		AND 	ptpp.planilla	= @planilla;
	
	if @generar_factura is null or @generar_factura = 'N' then  		
		return;  	
	end if;    	                                                           	

	
	if @concepto is null or @concepto = 0 then  		
		rollback;  		
		raiserror 99999 '<*Debe ingresar el Concepto Factura para el Tipo Proceso Nº '|| @tipo_proceso || '*>';  		
		return;  	
	end if;
	/*
	* CALCULAMOS en base al porcetaje de IVA obtenido de tipos_procesos_planillas
	* SI IVA>0 entonces modificamos el codigo anterior que generaba todo en EXENTO.
	* CR:03/10/2015 20:45 =(    	                                                           	
	*/
	set @forma_pago				= 'C';  	
	set @factura_fisica			= '';  	
	set @saldo					= 0;  	
	set @tipo_de_factura 		= 'C';  	
	set @factor_cambio			= 1;  	
	set @empresa				= 1;  	
	set @item					= 1;  	

		set @ImporteFacturaTOT= isnull(@importe,0) + abs(isnull(@montodescuentos,0));
	IF @generaIVA = 0 
	THEN 
		set @monto_gravado			= 0;  	
		set @monto_exento			= @ImporteFacturaTOT;  	
		set @monto_impuesto			= 0;  	
		set @monto_gravado5			= 0;   	
		set @monto_impuesto5		= 0;  	
		set @monto_total10			= 0;     	
		set @monto_total5			= 0;     	
		set @porcentaje_impuesto	= 0;    	                                         	
	END IF;

	IF @generaIVA > 0 
	THEN 
		SET @MontoIVA	= ROUND(((@ImporteFacturaTOT * @generaIVA) / (100+@generaIVA)),0); 
		SET @MontoGRAV 	= @ImporteFacturaTOT - @MontoIVA;

		IF @generaIVA=5
		THEN
			set @monto_gravado			= 0;  	
			set @monto_exento			= 0;  	
			set @monto_impuesto			= 0;  	
			set @monto_gravado5			= @MontoGRAV ;   	
			set @monto_impuesto5		= @MontoIVA;  	
			set @monto_total10			= 0;     	
			set @monto_total5			= @ImporteFacturaTOT;     	
			set @porcentaje_impuesto	= @generaIVA;
		ELSE
			set @monto_gravado			= @MontoGRAV ;  	
			set @monto_exento			= 0;  	
			set @monto_impuesto			= @MontoIVA;  	
			set @monto_gravado5			= 0;  	
			set @monto_impuesto5		= 0;  	
			set @monto_total10			= @ImporteFacturaTOT;     	
			set @monto_total5			= 0;     	
			set @porcentaje_impuesto	= @generaIVA;
		END IF;
	END IF;
	
	select 	proveedor  	  
	into 	@proveedor  	  
	from 	proveedores  	 
	where 	persona = @persona;    	
	
	if @proveedor is null then  		
		INSERT INTO proveedores(persona, observaciones)
		VALUES		(@persona,'');
		
			select 	proveedor  	  
			into 	@proveedor  	  
			from 	proveedores  	 
			where 	persona = @persona;    	
		
		SET @sms = 'Persona inexistente, insertado en proveedores.. ' || CONVERT(VARCHAR(20), @persona) || 'Prov:' || CONVERT(VARCHAR(20), @proveedor);
		PRINT @sms;
		
		/*rollback;  		
		raiserror 99999 '<*Error al generar Factura. Debe definir como Proveedor a la Persona '|| @persona || '*>';  		
		return;*/  	
	end if;  	  	                                 	
	
			select fn_actualizar_numero_factura() into @factura from dummy;	 	                                         	
			insert into pre_facturas_recibidas( factura,     	
											procesorrhh,
											fecha,     					
											forma_pago,     					
											proveedor,     					
											factura_fisica,     					
											moneda,     					
											monto_gravado,     					
											monto_exento,     					
											monto_impuesto,     					
											saldo,     					
											comentario,     					
											tipo_de_factura,     					
											factor_cambio,     					
											monto_gravado5,     					
											monto_impuesto5,     					
											monto_total10,     					
											monto_total5,     					
											sede,     					
											empresa )    		
									values ( @factura,     		
											@proceso,
											@fecha_proceso,     					
											@forma_pago,     					
											@proveedor,     					
											@factura_fisica,     					
											@moneda,     					
											@monto_gravado,     					
											@monto_exento,     					
											@monto_impuesto,     					
											@saldo,     					
											@comentario || ' PRE-OP:' || CONVERT(VARCHAR(20),@orden) ,     					
											@tipo_de_factura,     					
											@factor_cambio,     					
											@monto_gravado5,     					
											@monto_impuesto5,     					
											@monto_total10,     					
											@monto_total5,     					
											@sede,     					
											@empresa );    	
											if @@error <> 0 then  		
												rollback;  		
												raiserror 99999 '<*Error al insertar en Facturas Recibidas. Proceso Sueldo: '|| @proceso || ', Persona: ' || @persona || ', Sede: '|| @sede || '*>';  		
												return;  	
											end if;    	                                          	
									
	insert into pre_facturas_recibidas_conceptos( factura,     					
											item,     					
											concepto,     					
											monto,     					
											monto_impuesto,     					
											porcentaje_impuesto )    		
									values ( @factura,     					
											@item,     					
											@concepto,     					
											(@importe+ @montodescuentos),  					
											(@monto_impuesto + @monto_impuesto5),     					
											@porcentaje_impuesto 
											);
											if @@error <> 0 then  		
												rollback;  		
												raiserror 99999 '<*Error al insertar en Facturas Recibidas Conceptos. Proceso Sueldo: '|| @proceso || ', Persona: ' || @persona || ', Sede: '|| @sede || '*>';  		
												return;  	
											end if;    	                      	
			insert into pre_facturas_detalle( factura,     					
											cuota,     					
											fecha_vencimiento,     					
											monto,     					
											saldo,     					
											observacion 
											)    		
									values ( @factura,     					
											@item,     					
											@fecha_proceso,     					
											(@importe + @montodescuentos),     					
											(@importe + @montodescuentos),     					
											@comentario
											);    	
											if @@error <> 0 then  		
												rollback;  		
												raiserror 99999 '<*Error al insertar en Facturas Detalle (Cuotas). Proceso Sueldo: '|| @proceso || ', Persona: ' || @persona || ', Sede: '|| @sede || '*>';  		
												return;  	
											end if;    	                                                	
																
			INSERT INTO pre_ordenes_detalle( orden,     					
											item,     					
											factura,     					
											cuota,     					
											monto,     					
											monto_pago,     					
											observacion 
											)    		
									VALUES ( @orden,     					
											@item,     					
											@factura,     					
											@item,     					
											(@importe + @montodescuentos),     					
											(@importe + @montodescuentos),     					
											@comentario
											);    	
											if @@error <> 0 then  		
												rollback;  		
												raiserror 99999 '<*Error al insertar en Ordenes Detalle la Factura generada. Proceso Sueldo: '|| @proceso || ', Persona: ' || @persona || ', Sede: '|| @sede || '*>';  		
												return;  	
											end if;    

END
