import pyodbc
conn_str = r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;'
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()
cursor.execute("SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME IN ('Usuarios', 'Paseadores', 'Paseos')")
res = '\n'.join([str(x) for x in cursor.fetchall()])
with open('schema.txt', 'w') as f:
    f.write(res)
