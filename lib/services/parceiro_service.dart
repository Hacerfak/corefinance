import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class ParceiroService {
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> buscarParceiros(String empresaId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'parceiros',
      where: 'empresa_id = ?',
      whereArgs: [empresaId],
      orderBy: 'nome ASC',
    );
  }

  Future<void> salvarParceiro({
    String? id,
    required String empresaId,
    required String documento,
    required String nome,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final data = {
      'empresa_id': empresaId,
      'documento': documento,
      'nome': nome,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (id == null) {
      data['id'] = _uuid.v4();
      await db.insert(
        'parceiros',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update('parceiros', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Função chamada exclusivamente pelo Leitor de XML
  Future<void> salvarParceiroDoXml({
    required String empresaId,
    required String documento,
    required String nome,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final existente = await db.query(
      'parceiros',
      where: 'empresa_id = ? AND documento = ?',
      whereArgs: [empresaId, documento],
    );

    if (existente.isEmpty) {
      await db.insert('parceiros', {
        'id': _uuid.v4(),
        'empresa_id': empresaId,
        'documento': documento,
        'nome': nome,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      // Se já existe, atualiza o nome com a informação mais recente da Nota Fiscal
      await db.update(
        'parceiros',
        {'nome': nome},
        where: 'id = ?',
        whereArgs: [existente.first['id']],
      );
    }
  }

  Future<void> excluirParceiro(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('parceiros', where: 'id = ?', whereArgs: [id]);
  }
}
