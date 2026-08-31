import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

/// Detalle / edicion: editar texto, reproducir audio y agendar recordatorio.
class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.note});

  final Note note;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.note.title);
  late final TextEditingController _contentCtrl =
      TextEditingController(text: widget.note.content);
  DateTime? _reminder;

  final AudioService _audio = AudioService();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reminder = widget.note.reminderDate;

    _subs.add(_audio.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    }));
    _subs.add(_audio.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    }));
    _subs.add(_audio.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    }));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  bool get _hasAudio =>
      widget.note.audioPath != null && widget.note.audioPath!.isNotEmpty;

  Future<void> _togglePlay() async {
    if (!_hasAudio) return;
    if (_playing) {
      await _audio.pausePlayback();
    } else {
      await _audio.play(widget.note.audioPath!);
    }
  }

  Future<void> _pickReminder() async {
    final DateTime now = DateTime.now();
    final DateTime base = _reminder ?? now.add(const Duration(hours: 1));

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;

    setState(() {
      _reminder =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _clearReminder() => setState(() => _reminder = null);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final Note updated = widget.note.copyWith(
      title: _titleCtrl.text.trim().isEmpty
          ? '(Sin titulo)'
          : _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      reminderDate: _reminder,
      clearReminder: _reminder == null,
    );

    await DatabaseService.instance.updateNote(updated);
    await NotificationService.instance.cancelReminder(updated);

    if (updated.reminderDate != null) {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.scheduleReminder(updated);
      if (mounted && updated.reminderDate!.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La fecha del recordatorio ya paso')),
        );
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await NotificationService.instance.cancelReminder(widget.note);
    if (widget.note.id != null) {
      await DatabaseService.instance.deleteNote(widget.note.id!);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  String _fmt(Duration d) {
    final String m = d.inMinutes.toString().padLeft(2, '0');
    final String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateFormat df = DateFormat('EEE d MMM y · HH:mm', 'es');
    final double maxMs =
        _duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de la nota'),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Titulo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text('Creada: ${df.format(widget.note.createdAt)}',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _contentCtrl,
            minLines: 5,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Texto transcrito',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Audio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_hasAudio)
            Row(
              children: [
                IconButton.filled(
                  onPressed: _togglePlay,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Slider(
                    value: _position.inMilliseconds
                        .clamp(0, maxMs.toInt())
                        .toDouble(),
                    max: maxMs,
                    onChanged: (v) =>
                        _audio.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Text('${_fmt(_position)} / ${_fmt(_duration)}',
                    style: theme.textTheme.bodySmall),
              ],
            )
          else
            Text('Esta nota no tiene audio asociado',
                style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          Text('Recordatorio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                _reminder == null ? Icons.alarm_off : Icons.alarm,
                color: _reminder == null
                    ? theme.colorScheme.outline
                    : theme.colorScheme.primary,
              ),
              title: Text(
                _reminder == null
                    ? 'Sin recordatorio'
                    : df.format(_reminder!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_reminder != null)
                    IconButton(
                      onPressed: _clearReminder,
                      icon: const Icon(Icons.clear),
                      tooltip: 'Quitar',
                    ),
                  TextButton(
                    onPressed: _pickReminder,
                    child: Text(_reminder == null ? 'Agendar' : 'Cambiar'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
