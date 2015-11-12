create PROC pag_confirmapreordenes_rrhh(@p_preorden	integer)
AS
BEGIN
	PRINT 'BEGIN:: pag_confirmapreordenes_rrhh' 

	DECLARE @CountFacturas			integer,
			@countFacturasRecibidas	integer,
			@sms					VARCHAR(2000)
			
	SELECT 	@CountFacturas = isnull(COUNT(1),0)
	FROM 	pre_ordenes_detalle pod
	WHERE 	pod.orden = @p_preorden

	SELECT @countFacturasRecibidas = isnull(COUNT(1),0) 
	FROM facturas_recibidas fr
	WHERE fr.factura IN (SELECT pod.factura
	                     FROM pre_ordenes_detalle pod 
	                     WHERE pod.orden = @p_preorden)
	                     
	IF @CountFacturas<> @countFacturasRecibidas
	BEGIN
		SELECT @sms = 'Existen pre-facturas pendientes de confirmacion. Facturas[' || CONVERT(VARCHAR(10),@countFacturasRecibidas )|| '] Pre-Facturas[' ||  CONVERT(VARCHAR(10),@countFacturas ) ||']'
		RAISERROR 99999 @sms
		RETURN -1 
	END
	 
	PRINT '1: insertando en ordenes_detalle'

		INSERT INTO ordenes(
		orden,
		fecha,
		persona,
		concepto_orden,
		total_a_pagar,
		moneda_factura,
		total_pago,
		moneda_pago,
		Cambio,
		comentario,
		sede,
		reposicion,
		empresa,
		proceso_sueldo,
		tipoorden) 
		SELECT 
		orden,
		getdate(), --fecha,
		persona,
		concepto_orden,
		total_a_pagar,
		moneda_factura,
		total_pago,
		moneda_pago,
		Cambio,
		comentario,
		sede,
		reposicion = NULL ,
		empresa,
		proceso_sueldo,
		tipoorden
		FROM pre_ordenes po
		WHERE po.orden = @p_preorden
	  
		IF @@error<>0 
		BEGIN
			RAISERROR 99999 '1: Error al insertar en ordenes>>pre_ordenes [pag_confirmapreordenes_rrhh]'
			RETURN -1 
		END
		
		PRINT '2: insertando en ordenes_detalle'
		
		INSERT INTO ordenes_detalle	(
			orden,
			item,
			factura,
			cuota,
			monto,
			monto_pago,
			observacion		)
		SELECT 
			orden,
			item,
			factura,
			cuota,
			monto,
			monto_pago,
			observacion
		FROM pre_ordenes_detalle 
		WHERE orden = @p_preorden

		IF @@error<>0 
		BEGIN
			RAISERROR 99999 '2: Error al insertar en ordenes_detalle>>pre_ordenes_detalle [pag_confirmapreordenes_rrhh]'
			RETURN -1 
		END

		PRINT '3: insertando en ordenes_valores'
		
		INSERT INTO ordenes_valores	(
			orden,
			item,
			forma_pago,
			monto_pago,
			cuenta_movto,
			docto_fecha,
			docto_nro,
			beneficiario,
			comentario,
			lugar_trabajo)
			SELECT 
			orden,
			item,
			forma_pago,
			monto_pago,
			cuenta_movto,
			getdate(), --docto_fecha,
			docto_nro,
			beneficiario,
			comentario,
			lugar_trabajo
		FROM pre_ordenes_valores pov
		WHERE pov.orden = @p_preorden

		IF @@error<>0 
		BEGIN
			RAISERROR 99999 '3: Error al insertar en ordenes_valores>>pre_ordenes_valores [pag_confirmapreordenes_rrhh]'
			RETURN -1 
		END
		
		UPDATE pre_ordenes
		SET	confirmado= 'S'
		WHERE orden = @p_preorden
		
PRINT 'FIN del proceso..'		
END
RETURN 0
