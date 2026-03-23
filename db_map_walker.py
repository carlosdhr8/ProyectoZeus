import pyodbc

conn_str = r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

try:
    cursor.execute("UPDATE Usuarios SET rol = 'paseador' WHERE email = '1@'")
    cursor.execute("UPDATE Paseadores SET usuario_email = '1@' WHERE id = 1")
    conn.commit()
    print("Mapeo de paseador completado con éxito")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
