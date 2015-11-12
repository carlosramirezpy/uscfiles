create PROC pag_confirmafacturas_rrhh(@p_factura	integer)
AS
BEGIN
			
	INSERT INTO facturas_recibidas
	(
		factura,
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
		reposicion,
		monto_gravado5,
		monto_impuesto5,
		monto_total10,
		monto_total5,
		asiento_generado,
		proceso,
		sede,
		empresa,
		responsable,
		recibido_docfisico,
		nrotimbrado,
		nrotimbrado_vencimiento
	)
		SELECT 		factura,
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
		reposicion,
		monto_gravado5,
		monto_impuesto5,
		monto_total10,
		monto_total5,
		asiento_generado,
		isnull(proceso,0),
		sede,
		empresa,
		responsable,
		recibido_docfisico,
		nrotimbrado,
		nrotimbrado_vencimiento
		FROM pre_facturas_recibidas pfr
		WHERE pfr.factura= @p_factura
		
		IF @@error<>0 
		BEGIN
			RAISERROR 99999 'Error al insertar en facturas_recibidas [pag_confirmafacturas_rrhh]'
			RETURN -1 
		END
		
		INSERT INTO facturas_detalle(
			factura,
			cuota,
			fecha_vencimiento,
			monto,
			saldo,
			observacion		)
		SELECT 			
			factura,
			cuota,
			fecha_vencimiento,
			monto,
			saldo,
			observacion
		FROM pre_facturas_detalle fd
		WHERE fd.factura = @p_factura
		IF @@error<>0 
		BEGIN
			RAISERROR 99999 'Error al insertar en facturas_detalle [pag_confirmafacturas_rrhh]'
			RETURN -1 
		END
		
		INSERT INTO facturas_recibidas_conceptos
		(	factura,
			item,
			concepto,
			monto,
			monto_impuesto,
			porcentaje_impuesto		)
		select factura,
			item,
			concepto,
			monto,
			monto_impuesto,
			porcentaje_impuesto
		from pre_facturas_recibidas_conceptos
		WHERE factura = @p_factura
		IF @@error<>0 
		BEGIN
			RAISERROR 99999 'Error al insertar en facturas_recibidas_conceptos [pag_confirmafacturas_rrhh]'
			RETURN -1 
		END
		
		UPDATE 	pre_facturas_recibidas
		SET		confirmado = 'S'
		where 	factura = @p_factura
		
END

