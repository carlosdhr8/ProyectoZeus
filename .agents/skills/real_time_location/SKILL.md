---
name: Implementación de Ubicación en Tiempo Real (GPS Tracking)
description: Guía paso a paso para implementar el rastreo GPS en tiempo real de mascotas mediante un paseador usando Flutter, FastAPI y WebSockets.
---

# 📍 Skill: Ubicación en Tiempo Real (Zeus Pet Care)

Esta habilidad proporciona el flujo de trabajo técnico exacto para implementar la funcionalidad de rastreo por GPS.

## 1. Requisitos y Dependencias
### 📱 Frontend (Flutter)
- `geolocator`: Para obtener las coordenadas GPS del dispositivo del paseador.
- `google_maps_flutter` o `flutter_map`: Para renderizar el mapa en la pantalla del dueño/admin.
- `web_socket_channel`: Para conectarse al túnel en tiempo real del servidor.
- `permission_handler`: Para solicitar permisos de ubicación en primer y segundo plano.

### ⚙️ Backend (Python - FastAPI)
- `websockets`: Para manejar conexiones bidireccionales concurrentes.
- `asyncio`: Para la ejecución asíncrona de los canales de comunicación.

## 2. Arquitectura de WebSockets
En lugar de peticiones HTTP tradicionales (REST), usaremos **WebSockets**. Esto permite que el celular del paseador "empuje" (push) nuevas ubicaciones al servidor cada 5 segundos, y el servidor a su vez se las "empuje" al celular del dueño de inmediato, sin requerir que la aplicación recargue la pantalla constantemente.

## 3. Plan de Implementación (Paso a Paso)

### Paso 1: Configurar WebSockets en FastAPI
1. Crear un `ConnectionManager` en `main_backend.py` para almacenar las conexiones activas agrupadas por `paseo_id` o `pet_id`.
2. Crear un endpoint `ws://` (ej. `/ws/paseo/{paseo_id}`).
3. Definir la lógica de "Broadcast": Si el Paseador A envía sus coordenadas `{"lat": 4.609, "lng": -74.081}`, el servidor las reenvía a todos los clientes (dueños/admins) suscritos a ese `paseo_id`.

### Paso 2: Permisos y Rastreo en el Paseador (Flutter)
1. Modificar `AndroidManifest.xml` e `Info.plist` para solicitar permisos de ubicación fina (`ACCESS_FINE_LOCATION`) y ubicación en segundo plano (`ACCESS_BACKGROUND_LOCATION`).
2. Crear una vista `PaseoActivoScreen` exclusiva para el paseador.
3. Usar `Geolocator.getPositionStream()` para capturar el cambio de ubicación constante y enviarlo a través del `WebSocketChannel`.

### Paso 3: Visualización del Mapa para el Dueño (Flutter)
1. Integrar un widget de Mapa (ej. `GoogleMap`).
2. Conectarse al mismo canal WebSocket usando `WebSocketChannel.connect(Uri.parse('ws://18.223.214.78:8000/ws/paseo/...'))`.
3. Al recibir un mensaje JSON con coordenadas, actualizar el estado (`setState`) de un marcador (`Marker`) en el mapa con un ícono personalizado.

### Paso 4: Manejo de Errores y Optimización
- Probar el consumo de batería ajustando la precisión de `geolocator` (ej. actualizar solo si el paseador se mueve más de 3 metros).
- Manejar desconexiones limpiamente (qué pasa si el paseador entra a un túnel sin internet temporalmente).

## 💡 Cómo invocar esta Skill
Cuando el usuario indique que desea iniciar esta funcionalidad, el agente de IA debe seguir estos 4 pasos cronológicamente y proponer el código necesario uno por uno, empezando siempre por el **Paso 1 (Backend WebSockets)**.
