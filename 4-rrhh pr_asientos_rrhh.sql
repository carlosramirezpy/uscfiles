--USE usc_rrhh;

create PROC pag_asientos_rrhh ( 	@p_proceso		integer,
								@p_planilla		integer,
								@p_procesoCTB	integer)
AS
BEGIN
PRINT '* ****************************'	
PRINT '* INICIO pag_asientos_rrhh (RRHH)'	
PRINT '* ****************************'	
DECLARE 	@c_nphID			integer,
			@c_ProcesoNOMBRE	VARCHAR(200),
			@c_PersonaNOMBRES	VARCHAR(200),
			@c_NovedadID		integer,
			@c_NovedadDESC		VARCHAR(100),
			@c_NovedadINGRESO	VARCHAR(1)	,
			@c_NovedadCTACTB	integer,
			@c_nphPERSONA		integer,
			@c_nphMONTO			MONEY,
			@c_nphCENTROCOSTO	integer,
			@c_ccSEDE			integer,
			@c_nphCOMENTARIO	VARCHAR(300),
			@c_TipoProcNovPla	VARCHAR(30)	,
			@c_TipoProcCTACTB	integer,
			@c_cuMONEDACTA		VARCHAR(2),
			@CodigoCorto		integer,
			@sms				VARCHAR(1000),
			@roww				integer,
			@rowwcount			integer,
			@fila				integer,
			@totalDesembolsar	MONEY  ,
			@asientoMax1		integer,
			@asientoMax1Tmp		integer,
			@personaANTERIOR			integer	,			
			@PersonaNOMBRESanterior		VARCHAR(200),
			@c_SucursalID		integer,
			@paramNovedadIPS	integer, -- parametros_codigos
			@paramPatronalIPS	NUMERIC(5,2), -- parametros_codigos
			@paramObreroIPS		NUMERIC(5,2), -- parametros_codigos
			@montoPatronal		MONEY,
			@paramIPSpatronalCtaCtb	integer ,
			@ccount 			integer


--	CREATE TABLE #novedades(
/*	CREAR EN LA BASE...PRUEBA-1
* 
* 	CREATE TABLE tmp_asientos_nph(
	nphID			integer,
	ProcesoID		integer,
	ProcesoNOMBRE	VARCHAR(200),
	PersonaNOMBRES	VARCHAR(200),
	NovedadID		integer,
	NovedadDESC		VARCHAR(100),
	NovedadINGRESO	VARCHAR(1)	,
	NovedadCTACTB	integer,
	nphPERSONA		integer,
	nphMONTO		MONEY,
	nphCENTROCOSTO	integer,
	ccSEDE			integer,
	nphCOMENTARIO	VARCHAR(300) 	NULL,
	TipoProcNovPla	VARCHAR(30)			,
	TipoProcCTACTB	integer			NULL,
	cuCUENTABANCO	integer				,
	cuMONEDACTA		VARCHAR(2)	
)
*/
	CREATE TABLE #novedades(
	nphID			integer,
	ProcesoID		integer,
	ProcesoNOMBRE	VARCHAR(200),
	PersonaNOMBRES	VARCHAR(200),
	NovedadID		integer,
	NovedadDESC		VARCHAR(100),
	NovedadINGRESO	VARCHAR(1)	,
	NovedadCTACTB	integer,
	nphPERSONA		integer,
	nphMONTO		MONEY,
	nphCENTROCOSTO	integer,
	ccSEDE			integer,
	nphCOMENTARIO	VARCHAR(300) 	NULL,
	TipoProcNovPla	VARCHAR(30)			,
	TipoProcCTACTB	integer			NULL,
	cuCUENTABANCO	integer				,
	cuMONEDACTA		VARCHAR(2)	
)
	
	CREATE TABLE #asociacion(
		TipoProcNovPla	VARCHAR(30)
	)
/*
* Limpiamos la tala de mensajes..
*/
	DELETE FROM tmpMensajesSP
	DELETE FROM tmp_asientos_nph	
	
/*#A
* Antes de cualquier cosa, se verifica lo primero, que el tipo de proceso 
* tenga configurado su cuenta contable	
*/
	SELECT 	@paramNovedadIPS 	= isnull(codigo_novedad_ips,50), 	
			@paramPatronalIPS	= isnull(pc.porcentaje_patronal_ips,16.5),
			@paramObreroIPS		=  isnull(pc.porcentaje_obrero_ips,9),
			@paramIPSpatronalCtaCtb	= 532002
	FROM 	parametros_codigos pc

	SELECT 	@CodigoCorto = isnull(tpp.ctactb_codigocorto,0) 
	FROM 	tipos_procesos_planillas tpp
	WHERE 	tpp.tipo_proceso = (SELECT ps.tipo_proceso
								FROM procesos_sueldos ps 
								WHERE ps.proceso=@p_proceso 
								AND tpp.planilla = @p_planilla)
								
	IF @CodigoCorto	=0 OR @CodigoCorto IS NULL  
 	BEGIN
		SELECT @sms = 'El tipo de proceso' || CONVERT(VARCHAR(10),@p_proceso) ||', en el modulo de RRHH, NO tiene configurado su cuenta contable en [tipos_procesos_planillas]'
		PRINT '%1!', @sms 
		
		insert into tmpMensajesSP(sms)
		VALUES( @sms)
		RETURN 0
	END
/*#A*/

--	INSERT INTO tmp_asientos_nph(	nphID,
	INSERT INTO #novedades(	nphID,
							ProcesoID,
							ProcesoNOMBRE,
							PersonaNOMBRES,
							NovedadID,
							NovedadDESC,
							NovedadINGRESO,
							NovedadCTACTB,
							nphPERSONA,
							nphMONTO,
							nphCENTROCOSTO,
							ccSEDE,
							nphCOMENTARIO,
							TipoProcNovPla,
							TipoProcCTACTB,
							cuCUENTABANCO,
							cuMONEDACTA	)
					SELECT	nphID			= nph.numero_interno,
							ProcesoID 		= nph.proceso,
							ProcesoNOMBRE	= ps.nombre,
							PersonaNOMBRES 	= p.primer_nombre || ' '|| p.primer_apellido,
							NovedadID		= n.novedad,
							NovedadDESC 	= n.nombre,
							NovedadINGRESO	= n.ingreso,
							NovedadCTACTB 	= (SELECT isnull(nf.ctactb_codigocorto,-1) FROM novedades_factores nf WHERE nf.novedad = n.novedad AND nf.planilla = nph.planilla),
							nphPERSONA		= nph.persona,
							nphMONTO 		= ROUND((nph.cantidad* nph.base * nph.factor) * (CASE n.ingreso WHEN 'S' THEN 1 ELSE -1 END),0) ,
							nphCENTROCOSTO	= nph.centro_de_costo,
							ccSEDE			= (SELECT cdc.sede FROM centros_de_costos cdc WHERE cdc.centro_de_costo = nph.centro_de_costo),
							nphCOMENTARIO	= isnull(nph.comentario,''),
							TipoProcNovPla 	=  ps.tipo_proceso || '/' || n.novedad || '/' || nph.planilla ,
							TipoProcCTACTB 	= (SELECT isnull(tpp.ctactb_codigocorto,-1)
											  FROM tipos_procesos_planillas tpp 
											  WHERE tpp.tipo_proceso = ps.tipo_proceso AND tpp.planilla = nph.planilla),
											  
							cuCUENTABANCO	= cu.banco,
							cuMONEDACTA		= (SELECT pcb.moneda FROM proxy_cuentas_bancarias pcb WHERE pcb.cuenta_banco = cu.banco)
					FROM	novedades_proceso_historico nph, 
							novedades n,
							procesos_sueldos ps,
							personas p, 
							cargos_unidades cu

					WHERE 	nph.novedad = n.novedad
					AND 	nph.persona = p.persona
					and 	nph.proceso = ps.proceso 
					and 	nph.proceso	= @p_proceso
					AND 	nph.planilla= @p_planilla
					
					AND 	nph.unidad_organica 	= cu.unidad_organica
					AND 	nph.lugar_de_trabajo 	= cu.lugar_de_trabajo
					AND 	nph.centro_de_costo 	= cu.centro_de_costo
					AND 	nph.persona				= cu.persona
					--and 	nph.persona IN (10000589)
					
					--and 	nph.persona IN ( 62, 90) /*temporal esto..por si queremos probar con algunas personas X nada mas..*/
					--AND 	nph.proceso IN (SELECT ot.proceso FROM ordenes_temporal ot) /* ver este control..pues ottmp es para saber que se envio a tesoreria nomas*/
					ORDER BY 	11, --centrocosto (sucursal o sede)
								3, 	--nombre
								n.ingreso DESC
		--
		--insertamos en una temporal, para obtener desde el cursor, y poder UPD la real(tmp_asientos_nph)
		--para que no cree problemas al cursor.	
		--estas tablas siempre deben ser igualitas..
		--		
		--IF EXISTS (SELECT 1 FROM tmp_asientos_nph)
		IF NOT EXISTS (SELECT 1 FROM #novedades)
		BEGIN 
			INSERT INTO tmpMensajesSP
			VALUES('No existen datos del Proceso[' || CONVERT(VARCHAR(10), @p_proceso) || '] Planilla[' || CONVERT(VARCHAR(10), @p_planilla)|| '] en Novedades Procesos Historico, del modulo de RRHH.')
			RETURN 1
			--SELECT * FROM tmp_asientos_nph
		END
		
/* 
* 1-insertamos las diferentes TipoPRoc/Novedad/Planilla
* que pueda estar configurado en CTB
* 2-verificamos c/u y actualizamos en el temporal.
* 3-al termino, verificamos si alguna novedad esta sin codigo configurable
* */					
	INSERT INTO #asociacion(TipoProcNovPla)
	SELECT DISTINCT TipoProcNovPla 
	FROM #novedades
 
	DECLARE cr_asociacion CURSOR FOR 
		SELECT TipoProcNovPla FROM #asociacion a
	
	OPEN cr_asociacion
	FETCH cr_asociacion INTO @c_TipoProcNovPla
	WHILE @@sqlstatus<>2 
	BEGIN
		SELECT 	@CodigoCorto=0
		SELECT 	@CodigoCorto = isnull(ac.CODIGO_CORTO,0)
		FROM 	ASOCIACION_CONTABLE ac /*proxy*/
		WHERE 	lower(ac.CLASIFICADOR) = 'rrhh_tipoproc_novedad_planilla'
		AND 	ac.CODIGO = @c_TipoProcNovPla
		
		IF @CodigoCorto>0
		BEGIN
			--2-update en la temporal tmp_asientos_nph
			UPDATE #novedades
			SET	NovedadCTACTB = @CodigoCorto
			WHERE  TipoProcNovPla = @c_TipoProcNovPla
		END
		FETCH cr_asociacion INTO @c_TipoProcNovPla
	END
	
	CLOSE cr_asociacion
	deallocate cursor cr_asociacion
 
	--IF EXISTS(SELECT 1 FROM tmp_asientos_nph WHERE NovedadCTACTB =-1)
	IF EXISTS(SELECT 1 FROM #novedades WHERE NovedadCTACTB =-1)
	BEGIN
		INSERT INTO tmpMensajesSP(sms)
		SELECT DISTINCT 'La Novedad [' || NovedadDESC || '] no tiene configurado CTACTB, p/ Proc/Novedad/Planilla [' || TipoProcNovPla || '] en Asociacion de Cuentas [rrhh_tipoproc_novedad_planilla]'
		FROM #novedades
		WHERE NovedadCTACTB =-1

		INSERT INTO tmpMensajesSP(sms)
		VALUES('Para configurar ingresar a RRHH:Menu> Archivo> Datos Basico> Novedades. Campo:[CtaCtb-Corto] de acuerdo a la planilla.')
		RETURN -1
		--SELECT * FROM tmpMensajesSP
	END
 
	/*--actualizamos la temporal real, por si existe una cuenta configurada especial.
	UPDATE 	tmp_asientos_nph
	SET		nph.NovedadCTACTB = t.NovedadCTACTB
	FROM 	#novedades t, tmp_asientos_nph nph
	WHERE 	t.TipoProcNovPla = nph.TipoProcNovPla
	*/
declare cr_Sucursal cursor for 
	SELECT 	distinct ccSEDE
	FROM 	#novedades 
	ORDER BY ccSEDE


declare cr_novedad cursor for 
	SELECT 	nphID,
			ProcesoNOMBRE,
			PersonaNOMBRES,
			NovedadID,
			NovedadDESC,
			NovedadINGRESO,
			NovedadCTACTB,
			nphPERSONA,
			nphMONTO,
			nphCENTROCOSTO,
			ccSEDE,
			nphCOMENTARIO,
			TipoProcNovPla,
			TipoProcCTACTB,
			cuMONEDACTA	 
	FROM 	#novedades /*== a tmp_asientos_nph*/
	WHERE 	ccSEDE = @c_SucursalID
	ORDER BY PersonaNOMBRES, NovedadINGRESO DESC , NovedadID 
	-- Muy importante que este ordenado,por nombre, pues usamos corte de control.
	-- En caso de estar desordenado, el control no funcionara y procesara mal los asientos.

	SELECT 	@roww=0,
			@fila=0,
			@totalDesembolsar = 0,
			@asientoMax1=0
						
	open cr_Sucursal
	fetch cr_Sucursal into 	@c_SucursalID
	while @@sqlstatus<>2 
	BEGIN
		PRINT 'SEDE:%1!',  @c_SucursalID
		SELECT 	@rowwcount = COUNT(*) 
		FROM 	#novedades
		WHERE 	ccSEDE = @c_SucursalID

		open cr_novedad
		fetch cr_novedad into 	@c_nphID,
								@c_ProcesoNOMBRE	,
								@c_PersonaNOMBRES	,
								@c_NovedadID		,
								@c_NovedadDESC		,
								@c_NovedadINGRESO	,
								@c_NovedadCTACTB	,
								@c_nphPERSONA		,
								@c_nphMONTO			,
								@c_nphCENTROCOSTO	,
								@c_ccSEDE			,
								@c_nphCOMENTARIO	,
								@c_TipoProcNovPla	,
								@c_TipoProcCTACTB	,
								@c_cuMONEDACTA
			while @@sqlstatus<>2 
			begin
				--processing selected row
				select 	@roww= @roww + 1
				
				/*aca debemos generar el asiento..*/
				IF @roww= 1
				BEGIN
					IF @asientoMax1=0
					BEGIN
						--la 1ra vez traemos el max desde CTB, los proximos ++1 nomas
						select 	@asientoMax1 = isnull(MAX(pa.asiento),0) + 1 
						FROM 	proxy_ASIENTOS pa 
						WHERE 	pa.PROCESO = @p_procesoCTB
						
						--max de la temporal de asientos,
						select 	@asientoMax1Tmp = isnull(MAX(tar.asiento),0) + 1 
						FROM 	tmp_asientos_rrhh tar 	
						WHERE 	tar.PROCESO = @p_procesoCTB
						
						--comparamos y tomamos el superior
						IF @asientoMax1< @asientoMax1Tmp 
						BEGIN
							SELECT @asientoMax1 = @asientoMax1Tmp 
						END
						
					END 
					ELSE
					BEGIN 
						--si ya se genero asiento, como se esta procesando desde RRHH, solo hacemos autonumerico..
						select @asientoMax1= @asientoMax1+1
					END
					
					select 	@personaANTERIOR = @c_nphPERSONA,
							@PersonaNOMBRESanterior = @c_PersonaNOMBRES
					--PRINT 'CAB..'
					--INSERT INTO proxy_ASIENTOS	(
					INSERT INTO tmp_asientos_rrhh	(
						PROCESO,
						ASIENTO,
						FECHA_CONTABLE,
						COMENTARIO,
						FECHA_ASIENTO,
						ESTADO,
						MONEDA,
						FACTOR_DE_CAMBIO,
						DOCTO_FISICO,
						TIPO_DE_ASIENTO,
						PROCESADO,
						CONTRA_ASIENTO,
						SUCURSAL,
						GENERADO
					)
					VALUES
					(
						@p_procesoCTB,
						@asientoMax1,
						convert(date,GETDATE()),
						CONVERT(VARCHAR(240), ('Asiento Generado from RRHH - Fecha: ' || CONVERT(VARCHAR(30), GETDATE())||' Proceso:' || CONVERT(VARCHAR(10), @p_proceso) || ' Planilla:' || CONVERT(VARCHAR(10), @p_planilla) || ' Suc:' || CONVERT(VARCHAR(3), @c_SucursalID))),
						convert(date,GETDATE()),
						'P',
						@c_cuMONEDACTA,
						1,
						'',
						1,
						'N',
						0,
						@c_ccSEDE,
						'S'	)
					PRINT '%1!', @c_PersonaNOMBRES
						
				END /* fin @roww==1*/
				
				IF  @personaANTERIOR<>@c_nphPERSONA
				BEGIN
					PRINT '%1! %2! %3! Salario NETO a Pagar',@c_cuMONEDACTA, @totalDesembolsar, @c_TipoProcCTACTB
					PRINT '.'
					PRINT '%1!', @c_PersonaNOMBRES
					/*	
					* persona diferente a anterior...
					* 
					* 1-insertamos el ultimo detalle
					* @totalDesembolsar a cuenta del proceso..
					* 2-Cerar @totalDesembolsar y @fila
					* */
					
					select @fila= @fila + 1
					--1
					INSERT INTO tmp_asientosdet_rrhh(			
						nphProcesoID,
						nphInternoID,
						nphPersona,
						PROCESO,
						ASIENTO,
						FILA,
						CUENTA,
						MONTO_DEBITO,
						MONTO_CREDITO,
						MONTO_DEBITO_ME,
						MONTO_CREDITO_ME,
						ACLARACION,
						SUCURSAL,
						CENTRO_DE_COSTO,
						EMPRESA,
						CODIGO_CORTO)
					VALUES(
						@p_proceso,
						@c_nphID,
						@c_nphPERSONA,
						@p_procesoCTB,
						@asientoMax1 ,
						@fila,
						convert(varchar(20), @c_TipoProcCTACTB),
						0,
						@totalDesembolsar,
						0,
						0,
						'Salario NETO a Pagar | ' || @PersonaNOMBRESanterior,
						@c_ccSEDE ,
						null,
						1,
						@c_TipoProcCTACTB)			


					--2
					select 	@totalDesembolsar = 0,
							@personaANTERIOR = @c_nphPERSONA,
							@PersonaNOMBRESanterior = @c_PersonaNOMBRES

				END	
					--PRINT 'DET..'
					/*
					* DETALLES DEL ASIENTO
					*/
					select 	@totalDesembolsar = @totalDesembolsar + @c_nphMONTO	,
							@fila = @fila + 1
					--INSERT INTO proxy_ASIENTOS_DETALLE(
					INSERT INTO tmp_asientosdet_rrhh(				
						nphProcesoID,
						nphInternoID,
						nphPersona,	
						PROCESO,
						ASIENTO,
						FILA,
						CUENTA,
						MONTO_DEBITO,
						MONTO_CREDITO,
						MONTO_DEBITO_ME,
						MONTO_CREDITO_ME,
						ACLARACION,
						SUCURSAL,
						CENTRO_DE_COSTO,
						EMPRESA,
						CODIGO_CORTO)
					VALUES	(
						@p_proceso,
						@c_nphID,
						@c_nphPERSONA,
						@p_procesoCTB,
						@asientoMax1 ,
						@fila,
						convert(varchar(20), @c_TipoProcCTACTB),
						CASE @c_NovedadINGRESO WHEN 'S' THEN abs(@c_nphMONTO) ELSE 0 END ,
						CASE @c_NovedadINGRESO WHEN 'N' THEN abs(@c_nphMONTO) ELSE 0 END ,
						0,
						0,
						@c_NovedadDESC || '-' ||  isnull(@c_nphCOMENTARIO,'') || ' | ' || @c_PersonaNOMBRES || ' | nphID:' || CONVERT(VARCHAR(10), @c_nphID) ,
						@c_ccSEDE ,
						null,
						1,
						@c_NovedadCTACTB)
						
					PRINT '%1! | %2! | %3! | %4!',@c_cuMONEDACTA, @c_nphMONTO, @c_NovedadCTACTB, @c_NovedadDESC
					
					--calculamos el 16,5% faltante para IPS
					IF @c_NovedadID = @paramNovedadIPS
					BEGIN 
						SELECT @montoPatronal = ROUND((@c_nphMONTO * @paramPatronalIPS) / @paramObreroIPS,0)
						
						--	-
						--	insertamos 16,5 DEBE
						select	@fila = @fila + 1
						INSERT INTO tmp_asientosdet_rrhh(		
							nphProcesoID,
							nphInternoID,	
							nphPersona,
							PROCESO,
							ASIENTO,
							FILA,
							CUENTA,
							MONTO_DEBITO,
							MONTO_CREDITO,
							MONTO_DEBITO_ME,
							MONTO_CREDITO_ME,
							ACLARACION,
							SUCURSAL,
							CENTRO_DE_COSTO,
							EMPRESA,
							CODIGO_CORTO)
						VALUES	(
							@p_proceso,
							@c_nphID * -1,
							@c_nphPERSONA,
							@p_procesoCTB,
							@asientoMax1 ,
							@fila,
							convert(varchar(20), @c_TipoProcCTACTB),
							abs(@montoPatronal),
							0,
							0,
							0,
							@c_NovedadDESC || ' Patronal(' || CONVERT(VARCHAR(10), @paramPatronalIPS) ||')' ||  ' | ' || @c_PersonaNOMBRES || ' | Calculado'  ,
							@c_ccSEDE ,
							null,
							1,
							@paramIPSpatronalCtaCtb)
						--	-
						--	insertamos 16,5 HABER
						select	@fila = @fila + 1
						INSERT INTO tmp_asientosdet_rrhh(		
							nphProcesoID,
							nphInternoID,	
							nphPersona,
							PROCESO,
							ASIENTO,
							FILA,
							CUENTA,
							MONTO_DEBITO,
							MONTO_CREDITO,
							MONTO_DEBITO_ME,
							MONTO_CREDITO_ME,
							ACLARACION,
							SUCURSAL,
							CENTRO_DE_COSTO,
							EMPRESA,
							CODIGO_CORTO)
						VALUES	(
							@p_proceso,
							@c_nphID *-1,
							@c_nphPERSONA,
							@p_procesoCTB,
							@asientoMax1 ,
							@fila,
							convert(varchar(20), @c_TipoProcCTACTB),
							0,
							abs(@montoPatronal),
							0,
							0,
							@c_NovedadDESC || '(' || CONVERT(VARCHAR(10), @paramPatronalIPS) ||')' ||  ' | ' || @c_PersonaNOMBRES || ' | Calculado'  ,
							@c_ccSEDE ,
							null,
							1,
							@c_NovedadCTACTB)
					
					END
					
				--si estamos en la ultima linea
				--debemos insertar el ultimo registro de la cuenta del proceso..
				--similar a cuando cambia de persona..
				IF @roww = @rowwcount
				BEGIN 
					--PRINT 'ULTIMA LINEA.. @totalDesembolsar = %1!', @totalDesembolsar
					select @fila= @fila + 1

					INSERT INTO tmp_asientosdet_rrhh(			
						nphProcesoID,
						nphInternoID,	
						nphPersona,
						PROCESO,
						ASIENTO,
						FILA,
						CUENTA,
						MONTO_DEBITO,
						MONTO_CREDITO,
						MONTO_DEBITO_ME,
						MONTO_CREDITO_ME,
						ACLARACION,
						SUCURSAL,
						CENTRO_DE_COSTO,
						EMPRESA,
						CODIGO_CORTO)
					VALUES	(@p_proceso,
						@c_nphID,
						@c_nphPERSONA,
						@p_procesoCTB,
						@asientoMax1 ,
						@fila,
						convert(varchar(20), @c_TipoProcCTACTB),
						0,
						@totalDesembolsar,
						0,
						0,
						'Salario NETO a Pagar | ' || @c_PersonaNOMBRES,
						@c_ccSEDE ,
						null,
						1,
						@c_TipoProcCTACTB)
					
					PRINT '%1! %2! %3! Salario NETO a Pagar',@c_cuMONEDACTA, @totalDesembolsar, @c_TipoProcCTACTB
				END 
		--		PRINT '*** roww[%1!] Asiento= %2! ***', @roww, @asientoMax1
		-- 		PRINT '@c_PersonaNOMBRES = %1!', @c_PersonaNOMBRES
		-- 		PRINT '@c_NovedadID = %1!',@c_NovedadID
		-- 		PRINT '@c_NovedadDESC = %1!',@c_NovedadDESC
		-- 		PRINT '@c_NovedadINGRESO = %1!',@c_NovedadINGRESO
		-- 		PRINT '@c_NovedadCTACTB = %1!',@c_NovedadCTACTB
		-- 		PRINT '@c_nphPERSONA = %1!',@c_nphPERSONA
		-- 		PRINT '@c_nphMONTO = %1!',@c_nphMONTO
		-- 		PRINT '@c_nphCENTROCOSTO = %1!',@c_nphCENTROCOSTO
		-- 		PRINT '@c_ccSEDE = %1!',@c_ccSEDE
		-- 		PRINT '@c_nphCOMENTARIO = %1!',@c_nphCOMENTARIO
		-- 		PRINT '@c_TipoProcNovPla = %1!',@c_TipoProcNovPla
		-- 		PRINT '@c_TipoProcCTACTB = %1!',@c_TipoProcCTACTB
		-- 		PRINT '@c_cuMONEDACTA = %1!',@c_cuMONEDACTA
		-- 		PRINT '@c_ProcesoNOMBRE = %1!',@c_ProcesoNOMBRE

				
				fetch cr_novedad into 	@c_nphID,
										@c_ProcesoNOMBRE	,
										@c_PersonaNOMBRES	,
										@c_NovedadID		,
										@c_NovedadDESC		,
										@c_NovedadINGRESO	,
										@c_NovedadCTACTB	,
										@c_nphPERSONA		,
										@c_nphMONTO			,
										@c_nphCENTROCOSTO	,
										@c_ccSEDE			,
										@c_nphCOMENTARIO	,
										@c_TipoProcNovPla	,
										@c_TipoProcCTACTB	,
										@c_cuMONEDACTA
			end
			close cr_novedad

		SELECT 	@roww=0,
				@fila=0,
				@totalDesembolsar = 0
		
		fetch cr_Sucursal into 	@c_SucursalID
	END
	close cr_Sucursal
	deallocate cursor cr_novedad
	deallocate cursor cr_Sucursal

	--una vez finalizado, actualizamos novedades procesos historico.
	--UPD de proceso, asiento, linea 
	
	PRINT '**Fin Proceso de Asientos.'
	PRINT 'Actualizacion de NovProcesosHistoricos'
	
	UPDATE novedades_proceso_historico
	SET
	    asiento_generado = tar.ASIENTO,
	    proceso_asiento = tar.PROCESO,
	    linea = tar.FILA
	FROM 	novedades_proceso_historico nph,
			tmp_asientosdet_rrhh tar
	WHERE 	nph.proceso 		= tar.nphProcesoID
	AND 	nph.numero_interno 	= tar.nphInternoID
	
	--UPD el proceso, para marcar como procesado.
	PRINT 'UPD de Procesos Sueldos. Asentado=S'
	UPDATE procesos_sueldos
	SET	asentado = 'S'
	WHERE proceso = @p_proceso
PRINT 'FIN SP'	
END 
PRINT '* <FIN SP> *'	

RETURN 0
