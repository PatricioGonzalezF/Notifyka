import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';

/// Fila de la lista principal: titulo, fecha y fragmento del texto.
class NoteListItem extends StatelessWidget {
  const NoteListItem({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String dateLabel =
        DateFormat('d MMM y · HH:mm', 'es').format(note.createdAt);
    final String snippet = note.content.trim().replaceAll('\n', ' ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          note.title.isEmpty ? '(Sin titulo)' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(dateLabel, style: theme.textTheme.bodySmall),
              ],
            ),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (note.audioPath != null && note.audioPath!.isNotEmpty)
              Icon(Icons.graphic_eq,
                  size: 18, color: theme.colorScheme.outline),
            if (note.reminderDate != null)
              Icon(Icons.alarm, size: 18, color: theme.colorScheme.primary),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
