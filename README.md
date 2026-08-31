# Notify

App móvil (Flutter) para **captura rápida de voz → transcripción automática → almacenamiento local → recordatorios por fecha**. Versión MVP.

✅ **Compila y corre en Android.** Verificado en emulador (Pixel, Android 15): pantalla
principal, grabación rápida con transcripción en vivo, guardado en SQLite (persiste
entre reinicios) y pantalla de detalle.

---

## 1. Requisitos verificados en este equipo

- **Flutter** 3.47.2 (canal stable) en `C:\src\flutter`.
- **Android Studio** 2026.1 + SDK en `C:\Users\H-\AppData\Local\Android\Sdk`.
- Componentes del SDK de Android que **hubo que instalar** (los pide la cadena de plugins):

  | Componente | Motivo |
  |---|---|
  | Platform **API 36** | `compileSdk` por defecto de Flutter |
  | Platform **API 35** | lo fija el plugin nativo `jni` (dep. de `record`) |
  | Platform **API 34** | lo fija `flutter_local_notifications` |
  | **NDK 28.2.13676358** (r28c) | lo piden `speech_to_text` y `jni` |
  | **CMake 3.22.1** | compilación nativa de `jni` |

  > El `sdkmanager` / `android.exe` del SDK instalado (build canary) **crashea**
  > (`0xC0000409`) al descargar paquetes grandes. El NDK se instaló bajando el ZIP
  > oficial a mano (`android-ndk-r28c-windows.zip`) y extrayéndolo en
  > `Sdk/ndk/28.2.13676358/`. Las plataformas y CMake sí entraron con
  > `android.exe sdk install "<paquete>"`.

## 2. Cómo se generó el proyecto

`bootstrap.ps1` hace, en orden:

1. `flutter create --org com.example --project-name notify --platforms=android,ios .`
2. Copia `_overlay/` encima (código `lib/`, `pubspec.yaml`, `AndroidManifest.xml`, `Info.plist`).
3. Parcha `android/app/build.gradle.kts`:
   - añade `id("org.jetbrains.kotlin.android")` — la plantilla de Flutter 3.47 usa el
     bloque `kotlin { compilerOptions { … } }` pero **no** aplica el plugin.
   - habilita `isCoreLibraryDesugaringEnabled` + `coreLibraryDesugaring("…desugar_jdk_libs:2.1.4")`
     (requerido por `flutter_local_notifications`).
4. Parcha `android/gradle.properties`: `android.builder.sdkDownload=false`
   (evita que AGP invoque el `android.exe` que crashea).
5. `flutter pub get`.

> `android/app/build.gradle.kts` mantiene `compileSdk = flutter.compileSdkVersion`
> (36) y `ndkVersion` comentado — la línea `ndkVersion = flutter.ndkVersion` la
> aporta el plugin `speech_to_text`, no la app.

## 3. Ejecutar

```bash
flutter emulators --launch pixel     # o conecta un teléfono con depuración USB
flutter run
```

APK de debug: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`.

## 4. Arquitectura

```
lib/
  main.dart                     # bootstrap + tema Material 3 + init de servicios
  models/note.dart              # modelo Note + (de)serialización a SQLite
  services/
    database_service.dart       # sqflite: CRUD sobre la tabla notes
    audio_service.dart          # record (grabar) + audioplayers (reproducir)
    speech_service.dart         # speech_to_text: transcripción en vivo
    notification_service.dart   # flutter_local_notifications + timezone
  screens/
    home_screen.dart            # lista ordenada por fecha + FAB de micrófono
    record_screen.dart          # grabación rápida: estado + transcripción + guardar
    note_detail_screen.dart     # editar texto, reproducir audio, agendar recordatorio
  widgets/
    note_list_item.dart         # fila: título, fecha, fragmento
    pulsing_mic.dart            # indicador animado de grabación
```

### Paquetes

| Función | Paquete |
|---|---|
| Voz → texto | `speech_to_text` |
| Grabar audio | `record` ^6.0.0 *(5.2.1 tenía deps internas incompatibles: `record_linux` vs `record_platform_interface`)* |
| Reproducir audio | `audioplayers` *(añadido: la pantalla de detalle reproduce el audio)* |
| Rutas del sistema de archivos | `path_provider`, `path` |
| Persistencia | `sqflite` |
| Notificaciones / recordatorios | `flutter_local_notifications`, `timezone` |
| Formato de fechas | `intl` |

## 5. Base de datos (SQLite, v1)

Tabla `notes`:

| Columna | Tipo | Notas |
|---|---|---|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `title` | TEXT NOT NULL | primera línea de la transcripción (o `Nota <fecha>` si está vacía) |
| `content` | TEXT NOT NULL | texto transcrito completo |
| `audioPath` | TEXT | ruta del `.m4a` en `app_flutter/` |
| `createdAt` | TEXT NOT NULL | ISO-8601 |
| `reminderDate` | TEXT | ISO-8601, nullable |

Orden de la lista principal: `ORDER BY datetime(createdAt) DESC`.

## 6. Flujo de la app

1. **Home** muestra las notas (título, fecha, fragmento). Íconos: 〰 si tiene audio, ⏰ si tiene recordatorio.
2. El **FAB de micrófono** abre *Grabación rápida*: al entrar empieza a grabar audio
   y a transcribir en tiempo real; botones **Detener** y **Guardar**. El título por
   defecto es la primera línea del texto.
3. Tocar una nota abre **Detalle**: editar el texto, reproducir el audio y
   **Agendar** un recordatorio con `showDatePicker` + `showTimePicker`. Al guardar
   se (re)programa la notificación local.

## 7. Permisos

**Android** (`android/app/src/main/AndroidManifest.xml`): `RECORD_AUDIO`,
`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`,
`RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `INTERNET` + `<queries>` para
`android.speech.RecognitionService`.

**iOS** (`ios/Runner/Info.plist`): `NSMicrophoneUsageDescription`,
`NSSpeechRecognitionUsageDescription`.

Los permisos en tiempo de ejecución los piden los propios plugins.

## 8. Limitaciones del MVP

- La transcripción depende del motor del dispositivo. **El emulador no trae el
  paquete de voz `es-ES`**, así que ahí la transcripción sale vacía (`SodaSpeechRecognizer:
  Failed to get language pack`). En un teléfono con español instalado funciona.
- El recordatorio se agenda por instante absoluto; no hay recordatorios recurrentes.
- La grabación es de una sola toma (no hay pausar/reanudar).
- Sin sincronización en la nube ni borrado de archivos de audio huérfanos.
- Warnings de build no bloqueantes: KGP en `record_android`/`speech_to_text`
  (Flutter avisa que en el futuro exigirá *Built-in Kotlin*), y avisos de
  `java.lang.System::load` de Gradle 9 sobre JDK.
