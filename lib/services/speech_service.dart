import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Resultado de intentar arrancar el reconocimiento de voz.
enum SpeechStartResult {
  /// Escuchando correctamente.
  listening,

  /// El motor de reconocimiento no está disponible en el dispositivo.
  unavailable,

  /// El motor existe pero no hay ningún idioma instalado.
  noLocale,
}

/// Reconocimiento de voz en tiempo real (`speech_to_text`).
///
/// Resuelve el mejor `localeId` disponible (prioriza español) y expone
/// callbacks de error para que la UI pueda informar al usuario en vez de
/// dejar la transcripción en blanco sin explicación.
class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  String? _resolvedLocaleId;

  /// Locale que se usará para escuchar (p. ej. `es_ES`). `null` si no hay ninguno.
  String? get resolvedLocaleId => _resolvedLocaleId;

  void Function(String errorMsg)? _onError;
  void Function(String status)? _onStatus;

  /// Inicializa el motor y resuelve el locale. Idempotente.
  Future<bool> ensureInitialized() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onError: (e) => _onError?.call(e.errorMsg),
        onStatus: (s) => _onStatus?.call(s),
      );
    } catch (_) {
      _available = false;
    }
    if (_available) {
      _resolvedLocaleId = await _resolveLocale();
    }
    if (kDebugMode) {
      debugPrint('[SpeechService] available=$_available '
          'locale=$_resolvedLocaleId');
      if (_available) {
        try {
          final l = await _speech.locales();
          debugPrint('[SpeechService] ${l.length} locales: '
              '${l.take(12).map((e) => e.localeId).join(", ")}');
        } catch (_) {}
      }
    }
    return _available;
  }

  /// Elige el mejor locale: `es_ES` › cualquier `es_*` › locale del sistema ›
  /// cualquier `en_*` › el primero de la lista.
  Future<String?> _resolveLocale() async {
    try {
      final List<LocaleName> locales = await _speech.locales();
      if (locales.isEmpty) return null;
      final List<String> ids = locales
          .map((l) => l.localeId.replaceAll('-', '_'))
          .toList(growable: false);

      String? firstWhere(bool Function(String) test) {
        for (final id in ids) {
          if (test(id)) return id;
        }
        return null;
      }

      return firstWhere((id) => id.toLowerCase() == 'es_es') ??
          firstWhere((id) => id.toLowerCase().startsWith('es')) ??
          await _systemLocaleId() ??
          firstWhere((id) => id.toLowerCase().startsWith('en')) ??
          ids.first;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _systemLocaleId() async {
    try {
      final LocaleName? system = await _speech.systemLocale();
      return system?.localeId.replaceAll('-', '_');
    } catch (_) {
      return null;
    }
  }

  /// Empieza a escuchar. Devuelve el estado del intento.
  Future<SpeechStartResult> start({
    required void Function(String text, bool isFinal) onResult,
    void Function(String errorMsg)? onError,
    void Function(String status)? onStatus,
  }) async {
    _onError = onError;
    _onStatus = onStatus;

    final bool ok = await ensureInitialized();
    if (!ok) return SpeechStartResult.unavailable;
    if (_resolvedLocaleId == null) return SpeechStartResult.noLocale;

    try {
      await _speech.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: true,
          localeId: _resolvedLocaleId,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 30),
        ),
      );
    } catch (e) {
      _onError?.call('error_client');
      return SpeechStartResult.unavailable;
    }
    return SpeechStartResult.listening;
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}
