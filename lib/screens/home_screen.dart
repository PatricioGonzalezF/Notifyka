import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/database_service.dart';
import '../widgets/note_list_item.dart';
import 'note_detail_screen.dart';
import 'record_screen.dart';

/// Pantalla principal: lista de notas ordenada por fecha + FAB de grabacion.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Note>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _notesFuture = DatabaseService.instance.getNotes();
    });
  }

  Future<void> _openRecorder() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const RecordScreen(),
        fullscreenDialog: true,
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openDetail(Note note) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => NoteDetailScreen(note: note)),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notify'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Note>>(
          future: _notesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: '${snapshot.error}',
                onRetry: _refresh,
              );
            }
            final List<Note> notes = snapshot.data ?? const [];
            if (notes.isEmpty) return const _EmptyView();

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: notes.length,
              itemBuilder: (context, index) => NoteListItem(
                note: notes[index],
                onTap: () => _openDetail(notes[index]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openRecorder,
        tooltip: 'Nueva nota de voz',
        child: const Icon(Icons.mic, size: 32),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.mic_none,
            size: 72, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Toca el microfono para crear tu primera nota de voz',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 56),
        const SizedBox(height: 12),
        Center(child: Text('No se pudieron cargar las notas\n$message',
            textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ),
      ],
    );
  }
}
