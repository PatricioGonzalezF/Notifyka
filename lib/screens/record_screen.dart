import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/speech_service.dart';
import '../widgets/pulsing_mic.dart';

/// Grabacion rapida: audio + transcripcion en tiempo real, detener y guardar.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final AudioService _audio = AudioService();
  final SpeechService _speech = SpeechService();

  String _finalText = '';
  String _partialText = '';
  bool _recording = false;
  bool _saving = false;
  bool _manualStop = false;
  String? _audioPath;

  /// Mensaje visible cuando la transcripcion no esta disponible o falla.
  String? _speechNotice;

  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // Control del reciclado de sesiones de `speech_to_text`.
  Timer? _speechRestartTimer;
  int _speechRestarts = 0;
  int _speechConsecutiveErrors = 0;
  bool _speechDisabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final bool granted = await _audio.hasPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de microfono denegado')),
      );
      Navigator.of(context).pop(false);
      return;
    }

    try {
      _audioPath = await _audio.startRecording();
    } catch (e) {
      _audioPath = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar la grabacion de audio: $e')),
        );
      }
    }

    await _startListening();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });

    if (mounted) setState(() => _recording = true);
  }

  Future<void> _startListening() async {
    if (_speechDisabled || _manualStop || _saving) return;

    final SpeechStartResult result = await _speech.start(
      onResult: (text, isFinal) {
        if (!mounted) return;
        if (text.trim().isNotEmpty) _speechConsecutiveErrors = 0;
        setState(() {
          if (isFinal) {
            _finalText = _join(_finalText, text);
            _partialText = '';
          } else {
            _partialText = text;
          }
        });
      },
      onStatus: (status) {
        // `speech_to_text` termina la sesion tras el silencio de `pauseFor` o al
        // cerrar un resultado. Si seguimos grabando, la reanudamos con un
        // pequeno retraso para no martillear el servicio.
        if (status == 'done' || status == 'notListening') {
          _scheduleSpeechRestart();
        }
      },
      onError: (errorMsg) {
        _speechConsecutiveErrors++;
        final bool fatal = _isFatalSpeechError(errorMsg) ||
            _speechConsecutiveErrors >= 3;
        if (fatal) _speechDisabled = true;
        if (mounted) {
          setState(() => _speechNotice = _friendlyError(errorMsg, fatal));
        }
        if (!fatal) _scheduleSpeechRestart();
      },
    );

    if (!mounted) return;
    setState(() {
      switch (result) {
        case SpeechStartResult.listening:
          if (_speechConsecutiveErrors == 0) _speechNotice = null;
          break;
        case SpeechStartResult.unavailable:
          _speechDisabled = true;
          _speechNotice =
              'Reconocimiento de voz no disponible en este dispositivo. '
              'Se guardara solo el audio; puedes escribir el texto despues.';
          break;
        case SpeechStartResult.noLocale:
          _speechDisabled = true;
          _speechNotice =
              'No hay ningun idioma de dictado instalado en el dispositivo. '
              'Se guardara solo el audio; puedes escribir el texto despues.';
          break;
      }
    });
  }

  void _scheduleSpeechRestart() {
    if (_speechDisabled || _manualStop || _saving || !_recording) return;
    if (_speechRestarts >= 120) {
      _speechDisabled = true;
      return;
    }
    _speechRestartTimer?.cancel();
    _speechRestartTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _speechDisabled || _manualStop || _saving || !_recording) {
        return;
      }
      _speechRestarts++;
      _startListening();
    });
  }

  bool _isFatalSpeechError(String raw) {
    return raw == 'error_language_unavailable' ||
        raw == 'error_language_not_supported' ||
        raw == 'error_client' ||
        raw == 'error_too_many_requests' ||
        raw == 'error_insufficient_permissions';
  }

  String _friendlyError(String raw, bool fatal) {
    switch (raw) {
      case 'error_language_unavailable':
      case 'error_language_not_supported':
        return 'El idioma de dictado no esta instalado en el dispositivo. '
            'Se guardara solo el audio; escribe el texto al abrir la nota.';
      case 'error_client':
      case 'error_too_many_requests':
        return 'El reconocimiento de voz no esta disponible en este dispositivo. '
            'Se guardara solo el audio; escribe el texto al abrir la nota.';
      case 'error_speech_timeout':
      case 'error_no_match':
        return fatal
            ? 'No se detecto voz. Se guardara solo el audio.'
            : 'No se detecto voz todavia. Sigue hablando...';
      case 'error_busy':
      case 'error_recognizer_busy':
        return 'El reconocedor de voz esta ocupado. Se guardara solo el audio.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Sin conexion para el dictado online. Se usara solo lo reconocido offline.';
      default:
        return 'Aviso de dictado: $raw';
    }
  }

  String _join(String a, String b) =>
      a.trim().isEmpty ? b.trim() : '${a.trim()} ${b.trim()}';

  String get _fullText => _join(_finalText, _partialText).trim();

  Future<void> _stop() async {
    _manualStop = true;
    _timer?.cancel();
    _speechRestartTimer?.cancel();
    await _speech.stop();
    try {
      await _audio.stopRecording();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    if (_recording) await _stop();

    final String text = _fullText;
    final String firstLine = text.split('\n').first.trim();
    final String title = firstLine.isEmpty
        ? 'Nota ${DateFormat('d MMM · HH:mm', 'es').format(DateTime.now())}'
        : (firstLine.length > 60
            ? '${firstLine.substring(0, 60)}...'
            : firstLine);

    final Note note = Note(
      title: title,
      content: text,
      audioPath: _audioPath,
      createdAt: DateTime.now(),
    );
    await DatabaseService.instance.insertNote(note);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _manualStop = true;
    _timer?.cancel();
    _speechRestartTimer?.cancel();
    _speech.cancel();
    _audio.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final String m = d.inMinutes.toString().padLeft(2, '0');
    final String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grabacion rapida'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PulsingMic(active: _recording),
                  const SizedBox(width: 16),
                  Text(_fmt(_elapsed), style: theme.textTheme.headlineMedium),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _recording ? 'Grabando...' : 'Detenido',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _recording
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
              if (_speech.resolvedLocaleId != null && _speechNotice == null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Dictado: ${_speech.resolvedLocaleId}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              ],
              if (_speechNotice != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _speechNotice!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      _fullText.isEmpty
                          ? 'La transcripcion aparecera aqui...'
                          : _fullText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _fullText.isEmpty
                            ? theme.colorScheme.outline
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_recording && !_saving) ? _stop : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Detener'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
