import pyodbc

conn_str = r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

try:
    cursor.execute("IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'rol' AND Object_ID = Object_ID(N'Usuarios')) ALTER TABLE Usuarios ADD rol VARCHAR(50) DEFAULT 'usuario'")
    cursor.execute("IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'usuario_email' AND Object_ID = Object_ID(N'Paseadores')) ALTER TABLE Paseadores ADD usuario_email VARCHAR(MAX) NULL")
    
    cursor.execute("UPDATE Usuarios SET rol = 'admin' WHERE email = 'admin@zeus.com'")
    cursor.execute("UPDATE Usuarios SET rol = 'usuario' WHERE rol IS NULL")
    conn.commit()
    print("Migración de BD completada")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
