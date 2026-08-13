import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'backup_service.dart';

class TransacaoService {
  final _uuid = const Uuid();

  Future<void> criarLancamento(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    data['id'] = _uuid.v4();
    data['created_at'] = DateTime.now().toIso8601String();
    await db.insert('transacoes', data);
    _tentarBackup();
  }

  Future<void> criarLancamentosEmLote(
    List<Map<String, dynamic>> lancamentos,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();

    for (var l in lancamentos) {
      l['id'] = _uuid.v4();
      l['created_at'] = DateTime.now().toIso8601String();
      batch.insert('transacoes', l);
    }

    await batch.commit();
    _tentarBackup();
  }

  // --- FUNÇÕES DE GESTÃO (CRUD) ---

  /// Busca TODOS os lançamentos (pagos e pendentes) pela data de VENCIMENTO
  Future<List<Map<String, dynamic>>> buscarLancamentos({
    required String empresaId,
    required DateTime mesReferencia,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final dataInicio = DateTime(
      mesReferencia.year,
      mesReferencia.month,
      1,
    ).toIso8601String().split('T')[0];
    final dataFim = DateTime(
      mesReferencia.year,
      mesReferencia.month + 1,
      0,
    ).toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT t.*, c.nome as categoria_nome 
      FROM transacoes t
      LEFT JOIN categorias c ON t.categoria_id = c.id
      WHERE t.empresa_id = ? 
        AND t.data_vencimento >= ? 
        AND t.data_vencimento <= ?
      ORDER BY t.data_vencimento DESC
    ''',
      [empresaId, dataInicio, dataFim],
    );
  }

  /// Busca APENAS os lançamentos PAGOS pela data de PAGAMENTO (Regime de Caixa)
  Future<List<Map<String, dynamic>>> buscarBalancete({
    required String empresaId,
    required DateTime mesReferencia,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final dataInicio = DateTime(
      mesReferencia.year,
      mesReferencia.month,
      1,
    ).toIso8601String().split('T')[0];
    final dataFim = DateTime(
      mesReferencia.year,
      mesReferencia.month + 1,
      0,
    ).toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT t.*, c.nome as categoria_nome 
      FROM transacoes t
      LEFT JOIN categorias c ON t.categoria_id = c.id
      WHERE t.empresa_id = ? 
        AND t.data_pagamento >= ? 
        AND t.data_pagamento <= ?
      ORDER BY t.data_pagamento DESC
    ''',
      [empresaId, dataInicio, dataFim],
    );
  }

  /// Busca os lançamentos para montar o DRE (Pode ser Competência ou Caixa)
  Future<List<Map<String, dynamic>>> buscarDRE({
    required String empresaId,
    required DateTime mesReferencia,
    bool regimeCaixa = false, // Novo parâmetro de controle
  }) async {
    final db = await DatabaseHelper.instance.database;
    final dataInicio = DateTime(
      mesReferencia.year,
      mesReferencia.month,
      1,
    ).toIso8601String().split('T')[0];
    final dataFim = DateTime(
      mesReferencia.year,
      mesReferencia.month + 1,
      0,
    ).toIso8601String().split('T')[0];

    // Define qual coluna do banco de dados será usada para o filtro
    final campoData = regimeCaixa ? 'data_pagamento' : 'data_competencia';

    return await db.rawQuery(
      '''
      SELECT t.valor, t.tipo, c.nome as categoria_nome, c.grupo_dre 
      FROM transacoes t
      LEFT JOIN categorias c ON t.categoria_id = c.id
      WHERE t.empresa_id = ? 
        AND t.$campoData >= ? 
        AND t.$campoData <= ?
    ''',
      [empresaId, dataInicio, dataFim],
    );
  }

  Future<void> atualizarLancamento(String id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('transacoes', data, where: 'id = ?', whereArgs: [id]);
    _tentarBackup();
  }

  Future<void> excluirLancamento(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('transacoes', where: 'id = ?', whereArgs: [id]);
    _tentarBackup();
  }

  Future<void> estornarPagamento(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transacoes',
      {'data_pagamento': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    _tentarBackup();
  }

  Future<void> registrarPagamento(String id, String dataPagamento) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transacoes',
      {'data_pagamento': dataPagamento},
      where: 'id = ?',
      whereArgs: [id],
    );
    _tentarBackup();
  }

  void _tentarBackup() {
    BackupService().fazerBackup().catchError((e) {
      print("Falha no backup: $e");
    });
  }
}
