import pyodbc

conn_str = r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

try:
    cursor.execute("IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'usuario_id' AND Object_ID = Object_ID(N'Paseadores')) ALTER TABLE Paseadores ADD usuario_id INT NULL")
    # For user 1@, we will set usuario_id = 8, for id = 1
    cursor.execute("UPDATE Paseadores SET usuario_id = 8 WHERE id = 1")
    conn.commit()
    print("Migración a usuario_id completada")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
