import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('corefinance.db');

    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS transacoes_bancarias (
        id TEXT PRIMARY KEY,
        empresa_id TEXT,
        fitid TEXT,
        data TEXT,
        valor REAL,
        descricao TEXT,
        tipo TEXT,
        conciliado INTEGER DEFAULT 0,
        transacao_sistema_id TEXT,
        contraparte_documento TEXT,
        created_at TEXT,
        UNIQUE(empresa_id, fitid)
      )
    ''');

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // <-- ATUALIZADO PARA VERSÃO 3
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE transacoes ADD COLUMN contraparte_documento TEXT',
      );
    }
    // NOVO: Criação da tabela de parceiros na atualização
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS parceiros (
          id TEXT PRIMARY KEY,
          empresa_id TEXT,
          documento TEXT,
          nome TEXT,
          created_at TEXT,
          UNIQUE(empresa_id, documento)
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE empresas (
        id $idType,
        nome_fantasia $textType,
        cnpj TEXT UNIQUE NOT NULL,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE categorias (
        id $idType,
        empresa_id TEXT,
        nome $textType,
        grupo_dre $textType,
        tipo $textType,
        created_at TEXT,
        FOREIGN KEY (empresa_id) REFERENCES empresas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE parceiros (
        id $idType,
        empresa_id TEXT,
        documento TEXT,
        nome TEXT,
        created_at TEXT,
        UNIQUE(empresa_id, documento)
      )
    ''');
    await db.execute('''
      CREATE TABLE transacoes (
        id $idType,
        empresa_id TEXT,
        categoria_id TEXT,
        documento TEXT,
        contraparte_documento TEXT,
        descricao $textType,
        tipo $textType,
        valor $realType,
        data_competencia $textType,
        data_vencimento $textType,
        data_pagamento TEXT,
        chave_nfe TEXT,
        created_at TEXT,
        FOREIGN KEY (empresa_id) REFERENCES empresas (id) ON DELETE CASCADE,
        FOREIGN KEY (categoria_id) REFERENCES categorias (id) ON DELETE SET NULL
      )
    ''');
  }
}
