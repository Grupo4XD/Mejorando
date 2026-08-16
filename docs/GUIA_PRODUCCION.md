# Guía técnica y de producción de Rockify

## Resultado

El repositorio queda dividido en `lib/`, el cliente Flutter, y `backend/`, una API privada NestJS. La API usa PostgreSQL, Prisma, JWT, Socket.IO y OAuth PKCE de Spotify.

El flujo es: la app obtiene una identidad anónima y un JWT; el anfitrión conecta Spotify; el backend crea una sala privada; los invitados se unen con código; y el backend valida cada búsqueda, cola, voto o salto. Los tokens de Spotify nunca salen del backend.

## Tecnologías y motivos

| Tecnología | Motivo |
|---|---|
| Flutter | Un cliente mantenible para Android e iOS. |
| NestJS + TypeScript | API modular, validación, guardas JWT y WebSockets. |
| PostgreSQL | Relaciones y transacciones seguras para salas, miembros y votos. |
| Prisma | Esquema tipado y migraciones reproducibles. |
| Socket.IO | Sincroniza la sala sin que cada invitado haga polling a Spotify. |
| `flutter_secure_storage` | Guarda el JWT en el almacenamiento protegido del dispositivo. |
| PKCE + AES-256-GCM | Evita secretos OAuth en Flutter y cifra los tokens persistidos. |

## Arquitectura y patrones

Flutter usa estructura por funcionalidad: `auth`, `home` y `rooms`; cada una separa presentación, datos y dominio. La pantalla usa repositorios y `RoomController`, no HTTP ni Spotify directamente.

NestJS está separado en módulos `auth`, `spotify` y `rooms`. Los controladores reciben HTTP, los servicios contienen reglas de negocio, los DTO validan entrada, JWT protege rutas y Prisma persiste los datos. La base contiene `User`, `SpotifyConnection`, `PkceSession`, `Room`, `RoomMember` y `Vote`.

## Qué estaba mal antes

- El secreto Spotify vivía en Flutter y podía extraerse de APK o web.
- Los access y refresh tokens se distribuían mediante Firestore.
- Un nombre de texto decidía quién era anfitrión; no había identidad real.
- Las reglas Firestore eran abiertas y ya estaban vencidas.
- Los códigos de cuatro dígitos eran adivinables y podían colisionar.
- El cliente decidía privilegios y saltos, por lo que podía modificarse.
- Cada teléfono llamaba Spotify repetidamente, consumiendo cuota y produciendo carreras.
- Una pantalla mezclaba UI, Firestore, OAuth, red y negocio.

## ¿Qué es PKCE?

PKCE significa Proof Key for Code Exchange. El teléfono crea un secreto temporal `code_verifier` y manda a Spotify solamente su hash `code_challenge`. Spotify exige el verificador original al intercambiar el código OAuth por tokens.

Rockify cifra el verificador temporal en el backend. Spotify vuelve a un callback HTTPS del backend, este intercambia el código y cifra los tokens. El deep link final solo devuelve estado y resultado, nunca token o código. Por eso no existe `client_secret` dentro de Flutter.

## ¿Cómo se conecta cualquier frontend con un backend?

1. El frontend autentica al usuario y recibe una credencial de sesión.
2. Llama endpoints HTTPS, por ejemplo `POST /api/rooms/ABC/join`.
3. Adjunta el JWT en `Authorization: Bearer <token>`.
4. El backend valida credencial, cuerpo y permisos.
5. El backend aplica negocio, consulta la base y devuelve solo datos autorizados.
6. Para tiempo real, el frontend abre un WebSocket autenticado y se suscribe a una sala.

En Rockify, `ApiClient` centraliza HTTP; `RoomsRepository` expone operaciones de producto; NestJS nunca confía en que el teléfono informe rol, votos ni token Spotify.

## ¿Cómo se combinan ambas lógicas y qué se crea primero?

Primero se diseña el contrato: casos de uso, permisos, datos de entrada/salida y errores. Después se construye un flujo vertical pequeño: autenticar, crear sala y leer sala. Luego se agregan unirse, búsqueda, cola, votos y tiempo real.

Flutter se ocupa de interfaz, sesión local y eventos; el backend se ocupa de OAuth, permisos, Spotify, códigos, transacciones y publicaciones. PostgreSQL es la fuente de verdad. Por ejemplo, un voto llama a `POST /rooms/:code/votes`; el backend comprueba membresía, registra un único voto, calcula el umbral en transacción y decide si llama a Spotify.

No se termina primero todo el frontend o todo el backend. Se define primero la API y datos, se implementa backend mínimo protegido y luego la pantalla que lo consume. Así no se inventan reglas en el cliente.

## ¿Cómo se conecta una base de datos de forma general?

Solo el backend conoce `DATABASE_URL`. Un ORM o driver abre la conexión, ejecuta consultas parametrizadas y transforma el resultado a una respuesta pública. La contraseña de base de datos nunca va en Flutter, navegador, Git ni archivos de ejemplo con valores reales.

Prisma lee `DATABASE_URL`, aplica migraciones y provee `PrismaService` a NestJS. Las claves únicas, índices, relaciones y transacciones resuelven integridad cuando varias personas entran o votan a la vez.

## Configuración manual

### 1. Requisitos

Instala Flutter estable, Node.js 22+, Docker Desktop y una cuenta Spotify Developer. Para producción usa PostgreSQL gestionado y un dominio HTTPS para la API.

### 2. Base local

```powershell
docker compose up -d
```

### 3. Variables backend

```powershell
Copy-Item backend/.env.example backend/.env
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

Pon un `JWT_SECRET` distinto, aleatorio y de al menos 32 caracteres. Usa el Base64 de 32 bytes como `TOKEN_ENCRYPTION_KEY`. No publiques `backend/.env`.

### 4. Spotify Dashboard

1. Crea una aplicación en Spotify Developer Dashboard.
2. Copia solo Client ID a `SPOTIFY_CLIENT_ID`.
3. Registra exactamente `https://api.tu-dominio.com/api/spotify/callback` como Redirect URI.
4. Pon el mismo valor en `SPOTIFY_REDIRECT_URI`.
5. Mantén `MOBILE_CALLBACK_URI=rockify://oauth/success`.
6. No uses ni copies `client_secret`: PKCE no lo necesita.

Spotify exige callback HTTPS. Para desarrollo expón la API con un túnel HTTPS y registra exactamente esa URL en Spotify y `.env`.

### 5. Backend

```powershell
Set-Location backend
npm install
npm run prisma:generate
npm run prisma:deploy
npm run start:dev
```

La API local queda en `http://localhost:3000/api`. `ALLOWED_ORIGINS` debe contener solamente dominios reales separados por comas. Producción requiere HTTPS detrás de Cloud Run, Render, Railway u otro proxy TLS.

### 6. Flutter

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.tu-dominio.com/api --dart-define=WS_BASE_URL=https://api.tu-dominio.com
```

En emulador Android local pueden omitirse los defines porque se usa `http://10.0.2.2:3000`. Un teléfono físico requiere IP/HTTPS accesible o dominio público.

### 7. Deep links

Android e iOS ya incluyen el esquema `rockify://oauth/success`. Antes de publicar, registra Android App Links e iOS Universal Links en el dominio. El esquema no lleva token ni código, pero los enlaces verificados evitan colisiones y mejoran la experiencia.

## Lista de producción

- Rota el secreto Spotify expuesto por la aplicación anterior y revoca sus tokens.
- Guarda entorno, claves de firma y despliegue en un gestor de secretos.
- Usa HTTPS, CORS exacto, rate limiting perimetral, WAF y logs sin tokens.
- Realiza backups de PostgreSQL, alertas y rotación de claves de cifrado.
- Firma Android con una clave fuera del repositorio.
- Crea `android/key.properties` y una clave release antes de generar un artefacto publicable; si falta, la configuración permite desarrollo con firma debug, que no se debe distribuir.
- Configura CI para `flutter analyze`, `flutter test`, `npm run lint`, `npm test`, migraciones de prueba y escaneo de secretos.
- Añade pruebas de servicio, integración PostgreSQL y flujos de crear/unirse/votar antes de publicar.
