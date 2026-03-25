import pyodbc

conn_str = r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

try:
    print("Creando tabla HistorialPaseos...")
    cursor.execute("""
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'HistorialPaseos')
    BEGIN
        CREATE TABLE HistorialPaseos (
            id INT IDENTITY(1,1) PRIMARY KEY,
            paseo_id INT NOT NULL,
            lat FLOAT NOT NULL,
            lng FLOAT NOT NULL,
            fecha_registro DATETIME DEFAULT GETDATE(),
            CONSTRAINT FK_HistorialPaseos_Paseos FOREIGN KEY (paseo_id) REFERENCES Paseos(id_paseo)
        );
        PRINT 'Tabla HistorialPaseos creada.';
    END
    ELSE
    BEGIN
        PRINT 'La tabla HistorialPaseos ya existe.';
    END
    """)
    conn.commit()
    print("Operación completada con éxito.")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
