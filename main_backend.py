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

class UpdateUserRoleRequest(BaseModel):
    user_id: int
    nuevo_rol: str

class UpdateWalkerInfoRequest(BaseModel):
    usuario_id: int
    experiencia: str
    biografia: str

@app.post("/login")
def login(user: LoginRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        # Modificación: extraemos 'id' y 'rol'
        cursor.execute("SELECT id, email, nombre_completo, edad, lugar_residencia, tipo_plan, foto, rol FROM Usuarios WHERE email = ? AND password = ?", (user.email, user.password))
        user_row = cursor.fetchone()

        if user_row:
            id_usuario = user_row[0]
            email_usuario = user_row[1]
            
            foto_usr_b64 = None
            if user_row[6]:
                try:
                    foto_usr_b64 = base64.b64encode(user_row[6]).decode('utf-8')
                except Exception:
                    pass
            
            # Dinamismo de Roles
            rol_usuario = user_row[7] if user_row[7] else 'usuario'
            es_admin = (rol_usuario == 'admin')
            es_paseador = (rol_usuario == 'paseador')

            if es_admin:
                # El admin ve todo
                pets_query = """
                    SELECT M.id, M.nombre, M.raza, M.tamano, M.peso, M.descripcion, M.edad, U.nombre_completo, M.usuario_email, M.tipo_plan, M.foto,
                           P.id as paseador_id, P.nombre_completo as paseador_nombre, P.experiencia, P.biografia, UP.foto
                    FROM Mascotas M
                    INNER JOIN Usuarios U ON M.usuario_email = U.email
                    LEFT JOIN Paseadores P ON M.paseador_id = P.id
                    LEFT JOIN Usuarios UP ON P.usuario_id = UP.id
                    ORDER BY M.usuario_email
                """
                cursor.execute(pets_query)
            elif es_paseador:
                # El paseador ve solo las mascotas vinculadas a su usuario_id en Paseadores
                pets_query = """
                    SELECT M.id, M.nombre, M.raza, M.tamano, M.peso, M.descripcion, M.edad, U.nombre_completo, M.usuario_email, M.tipo_plan, M.foto,
                           P.id as paseador_id, P.nombre_completo as paseador_nombre, P.experiencia, P.biografia, UP.foto
                    FROM Mascotas M
                    INNER JOIN Usuarios U ON M.usuario_email = U.email
                    INNER JOIN Paseadores P ON M.paseador_id = P.id
                    LEFT JOIN Usuarios UP ON P.usuario_id = UP.id
                    WHERE P.usuario_id = ?
                """
                cursor.execute(pets_query, (id_usuario,))
            else:
                # Un usuario normal ve solo sus mascotas
                pets_query = """
                    SELECT M.id, M.nombre, M.raza, M.tamano, M.peso, M.descripcion, M.edad, NULL, M.usuario_email, M.tipo_plan, M.foto,
                           P.id as paseador_id, P.nombre_completo as paseador_nombre, P.experiencia, P.biografia, UP.foto
                    FROM Mascotas M
                    LEFT JOIN Paseadores P ON M.paseador_id = P.id
                    LEFT JOIN Usuarios UP ON P.usuario_id = UP.id
                    WHERE M.usuario_email = ?
                """
                cursor.execute(pets_query, (email_usuario,))

            pets_rows = cursor.fetchall()

            mascotas = []
            for r in pets_rows:
                # Extraemos la foto de forma segura para la mascota
                foto_b64 = None
                if r[10]:
                    try:
                        foto_b64 = base64.b64encode(r[10]).decode('utf-8')
                    except Exception:
                        pass
                
                # Extraemos la foto de forma segura para el paseador
                foto_paseador_b64 = None
                if r[15]:
                    try:
                        foto_paseador_b64 = base64.b64encode(r[15]).decode('utf-8')
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
                        "biografia": r[14],
                        "foto": foto_paseador_b64
                    } if r[11] is not None else None
                }
                mascotas.append(pet)

            # NUEVO: LÓGICA DE EXPIRACIÓN AUTOMÁTICA EN LOGIN
            # Recorrer las mascotas y verificar si su último paseo permitido ya ocurrió.
            for pet in mascotas:
                if pet["plan_mascota"].lower() != "sin plan":
                    cursor.execute("SELECT limite_horas FROM Planes WHERE LOWER(nombre) = LOWER(?)", (pet["plan_mascota"],))
                    plan_r = cursor.fetchone()
                    limite_h = plan_r[0] if plan_r else 0
                    
                    if limite_h > 0:
                        # Fetch the number of walks taken AND check if the last walk's end time has passed
                        cursor.execute("""
                            SELECT COUNT(*), MAX(CAST(fecha_paseo AS DATETIME) + CAST(hora_fin AS DATETIME)) 
                            FROM Paseos P 
                            INNER JOIN Mascotas M ON P.pet_id = M.id
                            WHERE P.pet_id = ? AND P.fecha_creacion >= M.fecha_actualizacion_plan
                        """, (pet["id"],))
                        stats_row = cursor.fetchone()
                        paseos_consumidos = stats_row[0] if stats_row and stats_row[0] else 0
                        ultimo_fin = stats_row[1] if stats_row and stats_row[1] else None
                        
                        # Si ya se agendaron todos los paseos Y la fecha/hora del último paseo ya pasó, se expira el plan.
                        if paseos_consumidos >= limite_h and ultimo_fin is not None:
                            cursor.execute("SELECT GETDATE()")
                            ahora = cursor.fetchone()[0]
                            if ahora >= ultimo_fin:
                                cursor.execute("UPDATE Mascotas SET tipo_plan = 'Sin Plan' WHERE id = ?", (pet["id"],))
                                conn.commit()
                                pet["plan_mascota"] = "Sin Plan"

            # --- Información adicional si es PASEADOR ---
            walker_info = {"experiencia": "", "biografia": ""}
            if es_paseador:
                cursor.execute("SELECT experiencia, biografia FROM Paseadores WHERE usuario_id = ?", (id_usuario,))
                w_row = cursor.fetchone()
                if w_row:
                    walker_info["experiencia"] = w_row[0] or ""
                    walker_info["biografia"] = w_row[1] or ""

            return {
                "status": "success",
                "user_data": {
                    "id": id_usuario,
                    "email": email_usuario,
                    "nombre": user_row[2],
                    "edad": user_row[3],
                    "residencia": user_row[4],
                    "tipo_plan": user_row[5],
                    "foto": foto_usr_b64,
                    "rol": rol_usuario,
                    "es_admin": es_admin,
                    "es_paseador": es_paseador,
                    "walker_info": walker_info
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
        # Actualizamos la tabla Mascotas con el nuevo tipo_plan y la fecha
        cursor.execute("UPDATE Mascotas SET tipo_plan = ?, fecha_actualizacion_plan = GETDATE() WHERE id = ?", (req.tipo_plan, req.pet_id))
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

# Nota: El endpoint /upload-walker-photo fue eliminado ya que las fotos ahora son centralizadas en Usuarios.

@app.post("/upload-user-photo/{user_email}")
async def upload_user_photo_api(user_email: str, file: UploadFile = File(...)):
    conn = None
    try:
        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="El archivo está vacío")

        img = Image.open(io.BytesIO(contents))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        # Foto grande para el perfil
        img.thumbnail((600, 600))

        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='JPEG', quality=85)
        img_data = img_byte_arr.getvalue()

        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("UPDATE Usuarios SET foto = ? WHERE email = ?", (pyodbc.Binary(img_data), user_email))
        conn.commit()

        return {"status": "success", "message": "Foto de usuario guardada correctamente"}
    except Exception as e:
        print(f"Error subiendo foto de usuario: {str(e)}")
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

# Nuevo endpoint para ver todos los planes activos (Para Dropdown)
@app.get("/get_planes")
def get_planes():
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        # OPORTUNIDAD DE EXPIRAR PLANES GLOBALMENTE CADA VEZ QUE ENTRAN AL CALENDARIO/APP
        # Expiración lazy de planes
        cursor.execute("""
            UPDATE M 
            SET M.tipo_plan = 'Sin Plan'
            FROM Mascotas M
            INNER JOIN Planes PL ON LOWER(M.tipo_plan) = LOWER(PL.nombre)
            WHERE M.tipo_plan != 'Sin Plan'
              AND (
                  SELECT COUNT(*) FROM Paseos P WHERE P.pet_id = M.id AND P.fecha_creacion >= M.fecha_actualizacion_plan
              ) >= PL.limite_horas
              AND (
                  SELECT MAX(CAST(P2.fecha_paseo AS DATETIME) + CAST(P2.hora_fin AS DATETIME)) 
                  FROM Paseos P2 WHERE P2.pet_id = M.id AND P2.fecha_creacion >= M.fecha_actualizacion_plan
              ) <= GETDATE()
        """)
        conn.commit()

        cursor.execute("SELECT id, nombre, limite_horas FROM Planes WHERE activo = 1")
        rows = cursor.fetchall()
        return [{"id": r[0], "nombre": r[1], "limite_horas": r[2]} for r in rows]
    finally:
        if conn: conn.close()

# 3. Ver lista de todos los paseadores (Para que el admin elija uno en un Dropdown)
@app.get("/get_all_walkers")
def get_all_walkers():
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT P.id, P.nombre_completo, P.experiencia, P.biografia, U.foto 
            FROM Paseadores P
            LEFT JOIN Usuarios U ON P.usuario_id = U.id
            WHERE P.activo = 1
        """)
        rows = cursor.fetchall()
        
        walkers = []
        for r in rows:
            foto_b64 = None
            if r[4]:
                try:
                    foto_b64 = base64.b64encode(r[4]).decode('utf-8')
                except Exception:
                    pass
            walkers.append({
                "id": r[0], "nombre": r[1], "experiencia": r[2], "biografia": r[3], "foto": foto_b64
            })
        return walkers
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
        cursor.execute("SELECT tipo_plan, usuario_email, fecha_actualizacion_plan FROM Mascotas WHERE id = ?", (req.pet_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Mascota no encontrada.")
        
        plan_actual = str(row[0]).strip()
        dueno_actual = row[1]
        fecha_act = row[2]
        if not fecha_act or plan_actual.lower() == 'sin plan':
            raise HTTPException(status_code=400, detail="El cliente no tiene un plan activo para paseos.")

        cursor.execute("SELECT limite_horas FROM Planes WHERE LOWER(nombre) = LOWER(?)", (plan_actual,))
        plan_row = cursor.fetchone()
        
        limite_horas = plan_row[0] if plan_row else 0
        if limite_horas == 0:
            raise HTTPException(status_code=400, detail="El cliente no tiene un plan activo válido para paseos.")

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
        # Ojo: Aquí contamos solo los paseos QUE SE ASIGNARON (fecha_creacion) después de que el plan se activó
        # Así si el plan de 1 hora se venció y el admin "renueva/activa" el plan de nuevo, su `fecha_actualizacion_plan` cambia a HOY
        # y los paseos viejos (que se crearon ayer o antes) ya no contarán restando horas al nuevo paquete.
        cursor.execute("SELECT COUNT(*) FROM Paseos WHERE pet_id = ? AND fecha_creacion >= ?", (req.pet_id, fecha_act))
        paseos_usados = cursor.fetchone()[0]

        if paseos_usados >= limite_horas:
            raise HTTPException(status_code=400, detail=f"Límite de {limite_horas} horas alcanzado. La mascota debe renovar su plan para seguir sumando paseos.")

        cursor.execute(
            "INSERT INTO Paseos (pet_id, paseador_id, fecha_paseo, hora_inicio, hora_fin, creado_por_admin, fecha_creacion) VALUES (?, ?, ?, ?, ?, ?, GETDATE())",
            (req.pet_id, req.paseador_id, req.fecha.strftime('%Y-%m-%d'), req.hora_inicio.strftime('%H:%M:%S'), req.hora_fin.strftime('%H:%M:%S'), req.admin_email)
        )
        # SE ELIMINÓ LA ACTUALIZACIÓN AUTOMÁTICA A "SIN PLAN".
        # Ahora el plan solo debe expirar cuando la fecha y hora pasen realmente
            
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

# --- GESTIÓN DE ROLES (ADMIN) ---

@app.get("/get_all_users")
def get_all_users():
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT U.id, U.email, U.nombre_completo, U.rol, U.foto, P.experiencia, P.biografia 
            FROM Usuarios U
            LEFT JOIN Paseadores P ON U.id = P.usuario_id
            ORDER BY U.nombre_completo
        """)
        rows = cursor.fetchall()
        
        users = []
        for r in rows:
            foto_b64 = None
            if r[4]:
                try:
                    foto_b64 = base64.b64encode(r[4]).decode('utf-8')
                except Exception:
                    pass
            users.append({
                "id": r[0],
                "email": r[1],
                "nombre": r[2],
                "rol": r[3] if r[3] else 'usuario',
                "foto": foto_b64,
                "walker_info": {
                    "experiencia": r[5] or "",
                    "biografia": r[6] or ""
                }
            })
        return users
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.post("/update_user_role")
def update_user_role(req: UpdateUserRoleRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        # 1. Actualizar el rol en Usuarios
        cursor.execute("UPDATE Usuarios SET rol = ? WHERE id = ?", (req.nuevo_rol, req.user_id))
        
        # 2. Gestión de tabla Paseadores (Activo/Inactivo)
        if req.nuevo_rol == 'paseador':
            cursor.execute("SELECT nombre_completo FROM Usuarios WHERE id = ?", (req.user_id,))
            usr_row = cursor.fetchone()
            if usr_row:
                nombre = usr_row[0]
                cursor.execute("SELECT id FROM Paseadores WHERE usuario_id = ?", (req.user_id,))
                if not cursor.fetchone():
                    cursor.execute(
                        "INSERT INTO Paseadores (nombre_completo, experiencia, biografia, usuario_id, activo) VALUES (?, ?, ?, ?, 1)",
                        (nombre, "Sin experiencia cargada", "Biografía por definir", req.user_id)
                    )
                else:
                    cursor.execute("UPDATE Paseadores SET activo = 1 WHERE usuario_id = ?", (req.user_id,))
        else:
            # Si ya no es paseador, lo marcamos como inactivo para que no salga en listas de asignación
            cursor.execute("UPDATE Paseadores SET activo = 0 WHERE usuario_id = ?", (req.user_id,))
        
        conn.commit()
        return {"status": "success", "message": f"Rol actualizado a {req.nuevo_rol}"}
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@app.post("/update_walker_info")
def update_walker_info(req: UpdateWalkerInfoRequest):
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE Paseadores SET experiencia = ?, biografia = ? WHERE usuario_id = ?",
            (req.experiencia, req.biografia, req.usuario_id)
        )
        conn.commit()
        return {"status": "success", "message": "Información del paseador actualizada"}
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()
