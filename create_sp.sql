-- Procedimiento Almacenado para obtener el historial de un paseo específico
-- Asegura que solo se traigan los puntos asociados al ID único de la sesión.

CREATE PROCEDURE sp_ObtenerHistorialPorPaseo
    @id_paseo INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        lat, 
        lng, 
        fecha_registro
    FROM 
        HistorialPaseos
    WHERE 
        paseo_id = @id_paseo
    ORDER BY 
        fecha_registro ASC;
END
GO
