import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

/// Acceso a la base de datos local SQLite (`sqflite`).
///
/// Esquema (v1):
/// ```
/// CREATE TABLE notes (
///   id           INTEGER PRIMARY KEY AUTOINCREMENT,
///   title        TEXT    NOT NULL,
///   content      TEXT    NOT NULL,
///   audioPath    TEXT,
///   createdAt    TEXT    NOT NULL,
///   reminderDate TEXT
/// )
/// ```
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'notify.db';
  static const int _dbVersion = 1;
  static const String table = 'notes';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final String dir = await getDatabasesPath();
    final String path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $table (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            title        TEXT    NOT NULL,
            content      TEXT    NOT NULL,
            audioPath    TEXT,
            createdAt    TEXT    NOT NULL,
            reminderDate TEXT
          )
        ''');
      },
    );
  }

  /// Todas las notas ordenadas por fecha de creacion (mas recientes primero).
  Future<List<Note>> getNotes() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query(table, orderBy: 'datetime(createdAt) DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getNote(int id) async {
    final Database db = await database;
    final rows =
        await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<Note> insertNote(Note note) async {
    final Database db = await database;
    final Map<String, Object?> values = note.toMap()..remove('id');
    final int id = await db.insert(table, values);
    return note.copyWith(id: id);
  }

  Future<int> updateNote(Note note) async {
    final Database db = await database;
    return db.update(
      table,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final Database db = await database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
