/// Modelo de dominio para una nota de voz.
///
/// Se persiste en la tabla `notes` de SQLite. Las fechas se guardan como
/// texto ISO-8601 (`DateTime.toIso8601String`).
class Note {
  final int? id;
  final String title;

  /// Texto transcrito a partir del audio.
  final String content;

  /// Ruta absoluta del archivo de audio en el almacenamiento de la app.
  final String? audioPath;

  final DateTime createdAt;

  /// Fecha/hora del recordatorio. `null` si la nota no tiene recordatorio.
  final DateTime? reminderDate;

  const Note({
    this.id,
    required this.title,
    required this.content,
    this.audioPath,
    required this.createdAt,
    this.reminderDate,
  });

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? audioPath,
    DateTime? createdAt,
    DateTime? reminderDate,
    bool clearReminder = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      createdAt: createdAt ?? this.createdAt,
      reminderDate: clearReminder ? null : (reminderDate ?? this.reminderDate),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'audioPath': audioPath,
      'createdAt': createdAt.toIso8601String(),
      'reminderDate': reminderDate?.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      audioPath: map['audioPath'] as String?,
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      reminderDate: map['reminderDate'] == null
          ? null
          : DateTime.tryParse(map['reminderDate'] as String),
    );
  }

  /// Identificador estable (32 bits) para asociar la notificacion local.
  int get notificationId =>
      (id ?? createdAt.millisecondsSinceEpoch) % 0x7fffffff;
}
