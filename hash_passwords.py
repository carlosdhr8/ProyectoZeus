import pyodbc
import hashlib

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def migrate_passwords():
    conn_str = (
        "DRIVER={ODBC Driver 17 for SQL Server};"
        "SERVER=3.128.13.188;"
        "DATABASE=ZeusDB;"
        "UID=sa;"
        "PWD=Abcd1234.;"
        "TrustServerCertificate=yes;"
    )
    
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        # 1. Obtener todos los usuarios
        cursor.execute("SELECT email, password FROM Usuarios")
        usuarios = cursor.fetchall()
        
        print(f"Iniciando migración de {len(usuarios)} usuarios...")
        
        for email, plain_password in usuarios:
            # Si el password ya tiene 64 caracteres, asumimos que ya está hasheado
            # (SHA-256 produce un hex de 64 caracteres)
            if len(plain_password) == 64:
                print(f"Skipping {email}: ya parece estar hasheado.")
                continue
                
            hashed = hash_password(plain_password)
            
            # 2. Actualizar el password con el hash
            cursor.execute(
                "UPDATE Usuarios SET password = ? WHERE email = ?",
                (hashed, email)
            )
            print(f"Actualizado: {email}")
        
        conn.commit()
        print("Migración completada exitosamente.")
        
    except Exception as e:
        print(f"Error durante la migración: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    migrate_passwords()
