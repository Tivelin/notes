import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Database database = await _initDatabase();
  runApp(MyApp(database: database));
}

Future<Database> _initDatabase() async {
  var databasesPath = await getDatabasesPath();
  String path = join(databasesPath, 'notes_database.db');

  Database database = await openDatabase(
    path,
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE notes (id INTEGER PRIMARY KEY, note TEXT)',
      );
    },
    version: 1,
  );
  return database;
}

class MyApp extends StatelessWidget {
  final Database database;
  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(database: database),
    );
  }
}

class HomePage extends StatefulWidget {
  final Database database;
  const HomePage({super.key, required this.database});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final TextEditingController _textEditingController = TextEditingController();
  List<String> _notes = [];

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  _initializeDatabase() async {
    _refreshNotes();
  }

  _refreshNotes() async {
    final List<Map<String, dynamic>> notes =
        await widget.database.query('notes');
    setState(() {
      _notes = notes.map((noteMap) => noteMap['note'].toString()).toList();
    });
  }

  _addNote() async {
    if (_textEditingController.text.isNotEmpty) {
      await widget.database.insert(
        'notes',
        {'note': _textEditingController.text},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _textEditingController.clear();
      _refreshNotes();
    }
  }

  _deleteNote(BuildContext context, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Note'),
          content: const Text('Are you sure you want to delete this note?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (confirmed != null && confirmed) {
      await widget.database.delete(
        'notes',
        where: 'note = ?',
        whereArgs: [_notes[index]],
      );
      _refreshNotes();
    }
  }

  @override
  void dispose() {
    _closeDatabase();
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _closeDatabase() async {
    await widget.database.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQLite Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textEditingController,
              decoration: const InputDecoration(
                hintText: 'Enter a Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addNote,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Add Note'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  return Dismissible(
                    key: Key(_notes[index]),
                    onDismissed: (direction) {
                      _deleteNote(context, index);
                    },
                    background: Container(color: Colors.red),
                    child: ListTile(
                      title: Text(_notes[index]),
                      onLongPress: () {
                        _deleteNote(context, index);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
