import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notify/models/note.dart';

void main() {
  test('Note se serializa y deserializa conservando los campos', () {
    final Note original = Note(
      id: 1,
      title: 'Comprar pan',
      content: 'Comprar pan\ny leche',
      audioPath: '/data/note_1.m4a',
      createdAt: DateTime(2026, 8, 29, 10, 30),
      reminderDate: DateTime(2026, 8, 30, 9),
    );

    final Note restored = Note.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.content, original.content);
    expect(restored.audioPath, original.audioPath);
    expect(restored.createdAt, original.createdAt);
    expect(restored.reminderDate, original.reminderDate);
  });

  test('copyWith(clearReminder) elimina el recordatorio', () {
    final Note note = Note(
      title: 't',
      content: 'c',
      createdAt: DateTime(2026, 1, 1),
      reminderDate: DateTime(2026, 1, 2),
    );
    expect(note.copyWith(clearReminder: true).reminderDate, isNull);
  });

  testWidgets('La app arranca y muestra el titulo Notify',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: null, body: Text('Notify'))),
    );
    expect(find.text('Notify'), findsOneWidget);
  });
}
