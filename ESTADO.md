# Estado del proyecto — 2026-08-30 (sesión 2)

## ✅ Funciona (verificado en emulador Pixel / Android 15)

- El **APK de debug compila** y la app corre.
- **Home**: lista de notas por fecha + FAB de micrófono.
- **Grabación rápida**: graba audio (`record`), timer, estado, botones Detener/Guardar.
- **Guardado + persistencia**: SQLite (`notify.db`), sobrevive a cerrar la app.
- **Detalle**: editar texto, reproducir audio, agendar recordatorio.
- **Transcripción — código listo y robusto** (ver abajo). Falta probar la voz real
  en un dispositivo con reconocimiento de voz funcional.

## 🎤 Transcripción de voz — qué se hizo en la sesión 2

### Cambios de código (todos en `_overlay/` y `lib/`)

| Archivo | Cambio |
|---|---|
| `lib/services/speech_service.dart` | Ya no fija `es_ES` a mano. Resuelve el mejor locale disponible con `_speech.locales()`: `es_ES` › cualquier `es_*` › locale del sistema › `en_*` › el primero. Expone `resolvedLocaleId`. Callbacks `onError`. `try/catch` en `listen()`. Log de diagnóstico en debug (`[SpeechService] available=… locale=… N locales: …`). |
| `lib/screens/record_screen.dart` | Banner honesto cuando el dictado no está disponible / falla (antes: recuadro vacío sin explicación). Auto-reanuda la sesión de `speech_to_text` cuando termina por silencio (con retraso de 700 ms). Se rinde tras 3 errores seguidos o errores fatales (`error_language_unavailable`, `error_client`, …) y deja seguir grabando solo audio. Muestra `Dictado: es_ES`. Fallo de grabación de audio ya no es fatal. |
| `lib/services/audio_service.dart` | `RecordConfig` con `audioInterruption: none` (no pausa la grabación cuando el reconocedor toma el foco) + `AndroidRecordConfig(audioSource: mic, manageBluetooth: false)` para que grabar y transcribir convivan mejor en un teléfono real. |
| `lib/widgets/pulsing_mic.dart` | `withOpacity` → `withValues` (deprecación). |

`flutter analyze` limpio. Build OK.

### Por qué el EMULADOR no transcribe (es infraestructura del emulador, no el código)

Diagnóstico de esta sesión (logcat + settings):

1. **`com.google.android.tts` estaba DESHABILITADO** (`enabled=0`) → el `RecognitionService`
   por defecto no podía enlazarse. **Solucionado**: `adb shell pm enable com.google.android.tts`
   (y `com.google.android.as`).
2. **El emulador pone el micrófono en CERO** salvo que se arranque con `-allow-host-audio`
   ("Otherwise, zeroes out audio"). **Solucionado**: relanzado con
   `emulator -avd pixel -allow-host-audio`. Ahora enruta el micrófono del PC anfitrión.
3. **El modelo offline `es-ES` (SODA) no está descargado** y **el reconocedor online
   devuelve HTTP 401**. Ambos caminos (Ajustes ▸ "Offline speech recognition", y la
   API online de GSA) **exigen iniciar sesión con una cuenta de Google en el emulador**
   ("Sign in to make the Google Assistant yours"). Sin cuenta, no hay reconocimiento.
   → **No lo hago yo** (son credenciales del usuario).

Estado actual del emulador (procesos vivos): arrancado con `-allow-host-audio`,
paquetes de voz habilitados, `voice_recognition_service` =
`com.google.android.tts/…GoogleTTSRecognitionService`. El `SpeechService` resuelve
`locale=es_ES` y la UI se ve limpia ("Dictado: es_ES", sin errores en bucle).

## ▶️ Cómo probar la transcripción de verdad

### Opción A — Teléfono real (recomendado, definitivo)
1. Conecta el teléfono Android con **Depuración USB**.
2. `flutter devices` (debe aparecer).
3. `flutter run`
4. FAB ▸ concede permisos ▸ **habla en español** ▸ el texto aparece en vivo.
El teléfono ya tiene cuenta Google + español + stack de voz completo.

### Opción B — Emulador (necesita tu cuenta Google)
El emulador ya está lanzado con `-allow-host-audio`.
1. En el emulador: **Ajustes ▸ Passwords & accounts ▸ Add account** → inicia sesión
   con tu Google.
2. **Ajustes ▸ (busca) "Offline speech recognition"** → descarga **Español (España)**.
3. Abre Notify ▸ FAB ▸ **habla al micrófono de tu PC/laptop**.

Si `flutter run` no encuentra el emulador ya lanzado, relánzalo con:
```
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd pixel -allow-host-audio
```

## Entorno — componentes del SDK instalados (NO borrar)

Platforms API 34/35/36 · NDK 28.2.13676358 (r28c) · CMake 3.22.1.
Detalle y motivos: sección de la sesión 1 más abajo si aplica.

## Cambios del build (sesión 1, ya en disco)

- `android/app/build.gradle.kts`: plugin `org.jetbrains.kotlin.android`,
  core library desugaring, `ndkVersion` comentado.
- `android/gradle.properties`: `android.builder.sdkDownload=false`.
- `pubspec.yaml`: `record: ^6.0.0`.
- `lib/services/notification_service.dart`: `uiLocalNotificationDateInterpretation`.
- Borrado `notify/flutter/` (clon roto; el bueno está en `C:\src\flutter`).
