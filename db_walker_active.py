import pyodbc

conn_str = r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

try:
    # 1. Añadir columna activo a Paseadores
    cursor.execute("IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'activo' AND Object_ID = Object_ID(N'Paseadores')) ALTER TABLE Paseadores ADD activo BIT DEFAULT 1")
    # 2. Inicializar como activos a los que ya están vinculados
    cursor.execute("UPDATE Paseadores SET activo = 1")
    conn.commit()
    print("Columna 'activo' añadida y configurada con éxito")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
