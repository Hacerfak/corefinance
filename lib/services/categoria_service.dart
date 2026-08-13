import 'package:uuid/uuid.dart';
import 'database_helper.dart';

class CategoriaService {
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> buscarCategorias(String empresaId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'categorias',
      where: 'empresa_id = ?',
      whereArgs: [empresaId],
      orderBy: 'tipo ASC, grupo_dre ASC',
    );
  }

  Future<void> salvarCategoria({
    String? id,
    required String empresaId,
    required String nome,
    required String grupoDre,
    required String tipo,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final data = {
      'empresa_id': empresaId,
      'nome': nome,
      'grupo_dre': grupoDre,
      'tipo': tipo,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (id == null) {
      data['id'] = _uuid.v4();
      await db.insert('categorias', data);
    } else {
      await db.update('categorias', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> excluirCategoria(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }
}
