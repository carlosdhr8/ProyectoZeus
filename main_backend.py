from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi import UploadFile, File
from fastapi.responses import Response
from PIL import Image
from pydantic import BaseModel
import pyodbc
import io
import base64
from typing import Optional
from datetime import date, time

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

conn_str = (r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=3.128.13.188;DATABASE=ZeusDB;UID=sa;PWD=Abcd1234.;TrustServerCertificate=yes;')

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str
    nombre_completo: str
    edad: int
    lugar_residencia: str

# Ajuste: Se agregaron los campos necesarios para que coincida con el frontend
class UpdatePetRequest(BaseModel):
    id: int
    nombre: str
    raza: str
    tamano: str
    peso: float
    descripcion: str
    edad: int

class AddPetRequest(BaseModel):
    nombre: str
    raza: str
    tamano: str
    peso: float
    descripcion: str
    edad: int
    usuario_email: str

class UpdatePlanRequest(BaseModel):
    pet_id: int
    tipo_plan: str

class AsignarPaseadorRequest(BaseModel):
    pet_id: int
    paseador_id: int

class PaseoRequest(BaseModel):
    pet_id: int
    paseador_id: int
    fecha: date
    hora_inicio: time
    hora_fin: time
    admin_email: str
    es_admin: bool

@app.post("/login")
def login(user: LoginRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("SELECT email, nombre_completo, edad, lugar_residencia, tipo_plan FROM Usuarios WHERE email = ? AND password = ?", (user.email, user.password))
        user_row = cursor.fetchone()

        if user_row:
            email_usuario = user_row[0]
            es_admin = (email_usuario == "admin@zeus.com")

            if es_admin:
                # Agregamos el LEFT JOIN con Paseadores (P)
                pets_query = """
                    SELECT M.id, M.nombre, M.raza, M.tamano, M.peso, M.descripcion, M.edad, U.nombre_completo, M.usuario_email, M.tipo_plan, M.foto,
                           P.id as paseador_id, P.nombre_completo as paseador_nombre, P.experiencia, P.biografia
                    FROM Mascotas M
                    INNER JOIN Usuarios U ON M.usuario_email = U.email
                    LEFT JOIN Paseadores P ON M.paseador_id = P.id
                    ORDER BY M.usuario_email
                """
                cursor.execute(pets_query)
            else:
                # Agregamos el LEFT JOIN con Paseadores (P)
                pets_query = """
                    SELECT M.id, M.nombre, M.raza, M.tamano, M.peso, M.descripcion, M.edad, NULL, M.usuario_email, M.tipo_plan, M.foto,
                           P.id as paseador_id, P.nombre_completo as paseador_nombre, P.experiencia, P.biografia
                    FROM Mascotas M
                    LEFT JOIN Paseadores P ON M.paseador_id = P.id
                    WHERE M.usuario_email = ?
                """
                cursor.execute(pets_query, (email_usuario,))

            pets_rows = cursor.fetchall()

            mascotas = []
            for r in pets_rows:
                # Extraemos la foto de forma segura
                foto_b64 = None
                if r[10]:
                    try:
                        foto_b64 = base64.b64encode(r[10]).decode('utf-8')
                    except Exception:
                        pass

                # Construimos el diccionario incluyendo al paseador
                pet = {
                    "id": r[0], "nombre": r[1], "raza": r[2],
                    "tamano": r[3] or "No definido", "peso": float(r[4] or 0.0),
                    "descripcion": r[5] or "", "edad": int(r[6] or 0), "dueno": r[7], "usuario_email": r[8], "plan_mascota": r[9],
                    "foto": foto_b64,
                    # Evaluamos si la columna 11 (P.id) trae datos. Si es así, construimos el objeto paseador
                    "paseador": {
                        "id": r[11],
                        "nombre": r[12],
                        "experiencia": r[13],
                        "biografia": r[14]
                    } if r[11] is not None else None
                }
                mascotas.append(pet)

            return {
                "status": "success",
                "user_data": {
                    "email": user_row[0],
                    "nombre": user_row[1],
                    "edad": user_row[2],
                    "residencia": user_row[3],
                    "tipo_plan": user_row[4],
                    "es_admin": es_admin
                },
                "mascotas": mascotas
            }
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    finally:
        if conn: conn.close()

@app.post("/register")
def register(user: RegisterRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Usuarios (email, password, nombre_completo, edad, lugar_residencia, tipo_plan) VALUES (?, ?, ?, ?, ?, 'Sin Plan')",
                       (user.email, user.password, user.nombre_completo, user.edad, user.lugar_residencia))
        conn.commit()
        return {"status": "success"}
    finally:
        if conn: conn.close()

@app.post("/update_pet")
def update_pet(pet: UpdatePetRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        # CAMBIO: 'weight' por 'peso'
        cursor.execute(
            "UPDATE Mascotas SET nombre = ?, raza = ?, tamano = ?, peso = ?, descripcion = ?, edad = ? WHERE id = ?",
            (pet.nombre, pet.raza, pet.tamano, pet.peso, pet.descripcion, pet.edad, pet.id)
        )
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        # Es vital agregar este print para ver el error real en la consola de Python
        print(f"Error actualizando mascota: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.post("/update_plan")
def update_plan(req: UpdatePlanRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        # Actualizamos la tabla Usuarios con el nuevo tipo_plan
        cursor.execute("UPDATE Mascotas SET tipo_plan = ? WHERE id = ?", (req.tipo_plan, req.pet_id))
        conn.commit()
        return {"status": "success", "message": "Plan actualizado correctamente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.post("/add_pet")
def add_pet(pet: AddPetRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        # Insertamos y obtenemos el ID generado por SQL Server con OUTPUT INSERTED.id
        cursor.execute("""
            INSERT INTO Mascotas (nombre, raza, tamano, peso, descripcion, edad, usuario_email, tipo_plan)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?, ?, ?, ?, 'Sin Plan')
        """, (pet.nombre, pet.raza, pet.tamano, pet.peso, pet.descripcion, pet.edad, pet.usuario_email))
        new_id = cursor.fetchone()[0]
        conn.commit()
        return {"status": "success", "new_id": new_id, "message": "Mascota agregada correctamente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.delete("/delete_pet/{pet_id}")
def delete_pet(pet_id: int):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM Mascotas WHERE id = ?", (pet_id,))
        conn.commit()
        return {"status": "success", "message": "Mascota eliminada permanentemente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.post("/upload-pet-photo/{pet_id}")
async def upload_pet_photo_api(pet_id: int, file: UploadFile = File(...)):
    conn = None
    try:
        # 1. Leer el contenido una sola vez
        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="El archivo está vacío")

        # 2. Procesamiento de imagen con PIL
        img = Image.open(io.BytesIO(contents))

        # Convertir a RGB si es necesario (evita errores con PNG transparentes al guardar en JPEG)
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        img.thumbnail((500, 500))

        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='JPEG', quality=85)
        img_data = img_byte_arr.getvalue()

        # 3. Guardar en Base de Datos
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        # Asegúrate de que la columna 'foto' sea de tipo VARBINARY(MAX) o IMAGE
        cursor.execute("UPDATE Mascotas SET foto = ? WHERE id = ?", (pyodbc.Binary(img_data), pet_id))
        conn.commit()

        return {"status": "success", "message": "Foto guardada correctamente"}
    except Exception as e:
        print(f"Error: {str(e)}") # Esto saldrá en tu terminal de Python
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.get("/get-pet-photo/{pet_id}")
async def get_pet_photo(pet_id: int):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("SELECT foto FROM Mascotas WHERE id = ?", (pet_id,))
        row = cursor.fetchone()

        if row and row[0]:
            # Devolvemos los bytes directamente como una imagen JPEG
            return Response(content=row[0], media_type="image/jpeg")
        else:
            # Si no hay foto, puedes devolver un error 404 o una imagen por defecto
            raise HTTPException(status_code=404, detail="Foto no encontrada")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

# 3. Ver lista de todos los paseadores (Para que el admin elija uno en un Dropdown)
@app.get("/get_all_walkers")
def get_all_walkers():
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        # Se agrego el campo "biografia" a la consulta SQL
        cursor.execute("SELECT id, nombre_completo, experiencia, biografia FROM Paseadores")
        rows = cursor.fetchall()
        return [{"id": r[0], "nombre": r[1], "experiencia": r[2], "biografia": r[3]} for r in rows]
    finally:
        if conn: conn.close()

@app.post("/assign_walker")
def assign_walker(req: AsignarPaseadorRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()

        # Verificamos si el paseador y la mascota existen para evitar errores de integridad
        cursor.execute("UPDATE Mascotas SET paseador_id = ? WHERE id = ?", (req.paseador_id, req.pet_id))

        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Mascota no encontrada")

        conn.commit()
        return {"status": "success", "message": "Paseador asignado correctamente"}
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.post("/asignar_paseo")
def asignar_paseo(req: PaseoRequest):
    if not req.es_admin:
        raise HTTPException(status_code=403, detail="Acceso denegado. Solo administradores.")
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("SELECT tipo_plan, usuario_email FROM Mascotas WHERE id = ?", (req.pet_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Mascota no encontrada.")
        plan_actual = str(row[0]).lower().strip()
        dueno_actual = row[1]
        limites = {"basico": 8, "intermedio": 16, "avanzado": 24, "full": 24, "sin plan": 0}
        limite_horas = limites.get(plan_actual, 0)
        if limite_horas == 0:
            raise HTTPException(status_code=400, detail="El cliente no tiene un plan activo para paseos.")

        cursor.execute("""
            SELECT M.usuario_email
            FROM Paseos P
            INNER JOIN Mascotas M ON P.pet_id = M.id
            WHERE P.paseador_id = ?
              AND P.fecha_paseo = ?
              AND P.hora_inicio < ?
              AND P.hora_fin > ?
        """, (req.paseador_id, req.fecha.strftime('%Y-%m-%d'), req.hora_fin.strftime('%H:%M:%S'), req.hora_inicio.strftime('%H:%M:%S')))
        
        overlapping_owners = cursor.fetchall()
        for owner_row in overlapping_owners:
            if owner_row[0] != dueno_actual:
                raise HTTPException(status_code=400, detail="Horario no disponible: El paseador ya fue asignado a otro dueño a esa misma hora.")

        # ----- NUEVA VALIDACION DE LA MASCOTA -----
        cursor.execute("""
            SELECT P.id_paseo
            FROM Paseos P
            WHERE P.pet_id = ?
              AND P.fecha_paseo = ?
              AND P.hora_inicio < ?
              AND P.hora_fin > ?
        """, (req.pet_id, req.fecha.strftime('%Y-%m-%d'), req.hora_fin.strftime('%H:%M:%S'), req.hora_inicio.strftime('%H:%M:%S')))
        
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Horario no disponible: La mascota ya tiene un paseo programado en ese horario.")
        # ------------------------------------------

        mes, anio = req.fecha.month, req.fecha.year
        cursor.execute("SELECT COUNT(*) FROM Paseos WHERE pet_id = ? AND MONTH(fecha_paseo) = ? AND YEAR(fecha_paseo) = ?", (req.pet_id, mes, anio))
        paseos_mes = cursor.fetchone()[0]

        if paseos_mes >= limite_horas:
            raise HTTPException(status_code=400, detail=f"Límite alcanzado ({limite_horas} paseos/mes).")

        cursor.execute(
            "INSERT INTO Paseos (pet_id, paseador_id, fecha_paseo, hora_inicio, hora_fin, creado_por_admin) VALUES (?, ?, ?, ?, ?, ?)",
            (req.pet_id, req.paseador_id, req.fecha.strftime('%Y-%m-%d'), req.hora_inicio.strftime('%H:%M:%S'), req.hora_fin.strftime('%H:%M:%S'), req.admin_email)
        )
        conn.commit()
        return {"status": "success", "message": "Paseo asignado exitosamente."}
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.get("/mis_paseos/{pet_id}/{anio}/{mes}")
def mis_paseos(pet_id: int, anio: int, mes: int):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT p.id_paseo, p.fecha_paseo, p.hora_inicio, p.hora_fin, u.nombre_completo as nombre_paseador
            FROM Paseos p
            JOIN Paseadores u ON p.paseador_id = u.id
            WHERE p.pet_id = ? AND MONTH(p.fecha_paseo) = ? AND YEAR(p.fecha_paseo) = ?
        ''', (pet_id, mes, anio))
        
        columnas = [column[0] for column in cursor.description] if cursor.description else []
        pasos = []
        for row in cursor.fetchall():
            d = dict(zip(columnas, row))
            if d.get('fecha_paseo'): d['fecha_paseo'] = d['fecha_paseo'].strftime('%Y-%m-%d')
            if d.get('hora_inicio'): d['hora_inicio'] = str(d['hora_inicio'])
            if d.get('hora_fin'): d['hora_fin'] = str(d['hora_fin'])
            pasos.append(d)
        
        return {"mes": mes, "anio": anio, "paseos": pasos}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.get("/paseador_agenda/{paseador_id}/{anio}/{mes}")
def paseador_agenda(paseador_id: int, anio: int, mes: int):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT p.id_paseo, p.fecha_paseo, p.hora_inicio, p.hora_fin, m.nombre as nombre_mascota, m.usuario_email as nombre_dueno
            FROM Paseos p
            JOIN Mascotas m ON p.pet_id = m.id
            WHERE p.paseador_id = ? AND MONTH(p.fecha_paseo) = ? AND YEAR(p.fecha_paseo) = ?
        ''', (paseador_id, mes, anio))
        
        columnas = [column[0] for column in cursor.description] if cursor.description else []
        pasos = []
        for row in cursor.fetchall():
            d = dict(zip(columnas, row))
            if d.get('fecha_paseo'): d['fecha_paseo'] = d['fecha_paseo'].strftime('%Y-%m-%d')
            if d.get('hora_inicio'): d['hora_inicio'] = str(d['hora_inicio'])
            if d.get('hora_fin'): d['hora_fin'] = str(d['hora_fin'])
            pasos.append(d)
        
        return {"mes": mes, "anio": anio, "paseos": pasos}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()
