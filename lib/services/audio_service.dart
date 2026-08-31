import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Grabacion de audio (`record`) y reproduccion (`audioplayers`).
///
/// Los archivos se guardan en el directorio de documentos de la app
/// (`path_provider`) con el nombre `note_<epochMs>.m4a`.
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // --- Grabacion --------------------------------------------------------------

  /// Solicita/comprueba el permiso de microfono.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> isRecording() => _recorder.isRecording();

  /// Inicia la grabacion y devuelve la ruta destino del archivo.
  Future<String> startRecording() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String fileName = 'note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final String path = p.join(dir.path, fileName);
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        // La grabacion NO se pausa cuando `speech_to_text` toma el foco de audio,
        // para poder grabar el archivo y transcribir a la vez.
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
          // Evita que `record` cambie el modo del AudioManager (interfiere con
          // el reconocedor de voz del sistema).
          manageBluetooth: false,
        ),
      ),
      path: path,
    );
    return path;
  }

  /// Detiene la grabacion. Devuelve la ruta final del archivo (o `null`).
  Future<String?> stopRecording() => _recorder.stop();

  Future<Amplitude> currentAmplitude() => _recorder.getAmplitude();

  // --- Reproduccion ---------------------------------------------------------

  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  Future<void> play(String path) => _player.play(DeviceFileSource(path));
  Future<void> pausePlayback() => _player.pause();
  Future<void> stopPlayback() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
