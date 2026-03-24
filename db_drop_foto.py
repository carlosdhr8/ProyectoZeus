import pyodbc

conn_str = r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

try:
    cursor.execute("IF EXISTS(SELECT * FROM sys.columns WHERE Name = N'foto' AND Object_ID = Object_ID(N'Paseadores')) ALTER TABLE Paseadores DROP COLUMN foto")
    conn.commit()
    print("Columna 'foto' eliminada de Paseadores")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
