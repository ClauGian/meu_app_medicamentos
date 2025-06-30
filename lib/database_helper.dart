import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      print('DEBUG: Retornando instância existente do banco de dados');
      return _database!;
    }
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'medications.db');
      final database = await openDatabase(
        path,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE medications (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL,
              quantidade INTEGER NOT NULL,
              dosagem_diaria INTEGER NOT NULL,
              tipo_medicamento TEXT,
              frequencia TEXT,
              horarios TEXT,
              startDate TEXT,
              isContinuous INTEGER,
              foto_embalagem TEXT,
              skip_count INTEGER,
              cuidador_id TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY,
              name TEXT,
              phone TEXT,
              date TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS caregivers (
              id INTEGER PRIMARY KEY,
              name TEXT,
              phone TEXT
            )
          ''');
          await db.execute('CREATE INDEX idx_medications_id ON medications(id)');
          await db.execute('CREATE INDEX idx_medications_horarios ON medications(horarios)');
          await db.execute('CREATE INDEX idx_medications_startDate ON medications(startDate)');
          print('DEBUG: Criação das tabelas e índices concluída.');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE medications RENAME TO medications_old');
            await db.execute('''
              CREATE TABLE medications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nome TEXT NOT NULL,
                quantidade INTEGER NOT NULL,
                dosagem_diaria INTEGER NOT NULL,
                tipo_medicamento TEXT,
                frequencia TEXT,
                horarios TEXT,
                startDate TEXT,
                isContinuous INTEGER,
                foto_embalagem TEXT,
                skip_count INTEGER,
                cuidador_id TEXT
              )
            ''');
            await db.execute('''
              INSERT INTO medications (
                id, nome, quantidade, dosagem_diaria, tipo_medicamento, frequencia,
                horarios, startDate, isContinuous, foto_embalagem, skip_count, cuidador_id
              )
              SELECT id, nome, COALESCE(quantidade, 0), COALESCE(dosagem_diaria, 0),
                     tipo_medicamento, frequencia, horarios, startDate, isContinuous,
                     foto_embalagem, skip_count, cuidador_id
              FROM medications_old
            ''');
            await db.execute('DROP TABLE medications_old');
            print('DEBUG: Migração para versão 2 concluída.');
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE users ADD COLUMN date TEXT');
            print('DEBUG: Coluna date adicionada à tabela users.');
          }
        },
      );
      if (!database.isOpen) {
        throw Exception('Erro: Banco de dados não está aberto.');
      }
      try {
        await database.rawQuery('PRAGMA journal_mode=WAL;');
        print('DEBUG: Configuração PRAGMA journal_mode=WAL concluída');
      } catch (e) {
        print('DEBUG: Erro ao configurar PRAGMA journal_mode=WAL: $e');
      }
      print('DEBUG: openDatabase concluído: $database');
      return database;
    } catch (e) {
      print('DEBUG: Erro ao inicializar banco de dados: $e');
      rethrow;
    }
  }
}