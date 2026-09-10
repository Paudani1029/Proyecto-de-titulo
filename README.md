# lumina

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Estado actual del proyecto
 Pantalla principal (círculo de estado, descripción)
 Captura periódica con la cámara del teléfono (PhoneCameraService)
 Reconocimiento de objetos con Google ML Kit (Image Labeling)
 Traducción automática de las etiquetas (inglés → español), on-device
 Narración por voz (Text-to-Speech)

 ## Requisitos previos
 Flutter -- Extensión de VisualStudio Code
 Android Studio — developer.android.com/studio (se usa solo para obtener el Android SDK y, opcionalmente, un emulador — no para escribir código)
 Git
 Un celular Android (recomendado) o un emulador configurado en Android Studio

## Verificar la instalación

En una terminal, ejecutar:

flutter doctor

Debe mostrar en verde (✓) al menos: Flutter, Android toolchain, y algún dispositivo conectado. El ✗ de "Visual Studio - develop Windows apps" se puede ignorar — solo aplica si se quisiera compilar una app de escritorio para Windows, no para Android.

## Cómo clonar y correr el proyecto
git clone https://github.com/Paudani1029/Proyecto-de-titulo.git

descarga automáticamente todas las dependencias listadas en pubspec.yaml (http, camera, flutter_tts, google_mlkit_image_labeling, google_mlkit_translation, etc.)

flutter pub get

flutter run


## Preparar el celular para pruebas
 -Ajustes → Acerca del teléfono → tocar 7 veces "Número de compilación" (activa Opciones de desarrollador)
 -Ajustes → Opciones de desarrollador → activar Depuración USB
 -Conectar el celular por USB al computador y aceptar el mensaje de confianza que aparece en pantalla
 -Verificar que se detecta con:  flutter devices

 ## Primera ejecución

La primera vez que se corre flutter run en un computador nuevo, puede tardar bastante (varios minutos) porque Gradle descarga herramientas adicionales (NDK, dependencias de Android). Las siguientes veces es mucho más rápido.

La primera vez que la app reconoce un objeto, también puede tardar un poco más de lo normal: el modelo de traducción (~30 MB) se descarga una sola vez y necesita conexión a Internet/Wi-Fi en ese momento. Después queda guardado en el celular y funciona sin conexión.

## Flujo de trabajo en equipo (Git)
Antes de empezar a programar cada sesión:

git pull

Después de hacer cambios:

git add .
git commit -m "Descripción breve de lo que se hizo"
git push

## Problemas comunes y solución
### 'flutter' no se reconoce como un comando
Flutter está instalado pero no está en el PATH de Windows.

### flutter doctor marca "Android toolchain" con ✗ (Android SDK no encontrado)
Instalar Android Studio, abrirlo una vez para que descargue el SDK automáticamente (elegir instalación "Standard").

### Android license status unknown / sdkmanager not found

Bug conocido de las versiones más nuevas de las Command-line Tools de Android. Solución:

Android Studio → Tools → SDK Manager → pestaña SDK Tools
Desmarcar "Android SDK Command-line Tools (latest)"
Activar "Show Package Details"
Marcar la versión 22.0 (no la más reciente) → Apply
Cerrar y abrir de nuevo la terminal, ejecutar flutter doctor de nuevo

## Estructura del proyecto
app/
└──src/
    └──debug/
        └──main/
            └──AndroidManifest.xml   → Se agregan los permisos de la aplicación (<uses-permission android:name="android.permission.CAMERA" />) en la segunda linea (por si no te aparece)
lib/
├── main.dart                        → pantalla principal y lógica de la UI
└── services/
    ├── camera_service.dart          → interfaz común (contrato) para cualquier fuente de cámara
    ├── mock_camera_service.dart     → cámara simulada, útil para probar sin hardware
    ├── phone_camera_service.dart    → usa la cámara física del teléfono
    ├── esp_cam_service.dart         → (esqueleto) para la cámara real, pendiente de hardware
    ├── reconocimiento_service.dart  → reconocimiento de objetos con ML Kit
    ├── traduccion_service.dart      → traducción inglés → español on-device
    └── voz_service.dart             → texto a voz (narración)
pubspec.yaml                         → Se agregan las dependencias 