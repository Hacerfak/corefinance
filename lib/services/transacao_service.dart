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
      WHERE t.empresa_id = ? AND t.data_vencimento >= ? AND t.data_vencimento <= ?
      ORDER BY t.data_vencimento DESC
    ''',
      [empresaId, dataInicio, dataFim],
    );
  }

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
      WHERE t.empresa_id = ? AND t.data_pagamento >= ? AND t.data_pagamento <= ?
      ORDER BY t.data_pagamento DESC
    ''',
      [empresaId, dataInicio, dataFim],
    );
  }

  Future<List<Map<String, dynamic>>> buscarDRE({
    required String empresaId,
    required DateTime mesReferencia,
    bool regimeCaixa = false,
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
    final campoData = regimeCaixa ? 'data_pagamento' : 'data_competencia';
    return await db.rawQuery(
      '''
      SELECT t.valor, t.tipo, c.nome as categoria_nome, c.grupo_dre 
      FROM transacoes t
      LEFT JOIN categorias c ON t.categoria_id = c.id
      WHERE t.empresa_id = ? AND t.$campoData >= ? AND t.$campoData <= ?
    ''',
      [empresaId, dataInicio, dataFim],
    );
  }

  // ==========================================
  // NOVAS FUNÇÕES PARA CÁLCULO DE ACUMULADOS
  // ==========================================

  /// Calcula o saldo bancário/caixa histórico acumulado ATÉ o mês anterior
  Future<double> calcularSaldoAcumuladoAnterior({
    required String empresaId,
    required DateTime mesReferencia,
    required String campoData,
  }) async {
    final db = await DatabaseHelper.instance.database;
    // Pega o último dia do mês anterior
    final dataLimite = DateTime(
      mesReferencia.year,
      mesReferencia.month,
      0,
    ).toIso8601String().split('T')[0];

    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN tipo = 'ENTRADA' THEN valor ELSE 0 END) as entradas,
        SUM(CASE WHEN tipo = 'SAIDA' THEN valor ELSE 0 END) as saidas,
        SUM(CASE WHEN tipo = 'SALDO' THEN valor ELSE 0 END) as saldos
      FROM transacoes
      WHERE empresa_id = ? AND $campoData <= ? AND $campoData IS NOT NULL
    ''',
      [empresaId, dataLimite],
    );

    if (result.isNotEmpty) {
      final entradas = (result.first['entradas'] as num?)?.toDouble() ?? 0.0;
      final saidas = (result.first['saidas'] as num?)?.toDouble() ?? 0.0;
      final saldos = (result.first['saldos'] as num?)?.toDouble() ?? 0.0;
      return saldos + entradas - saidas;
    }
    return 0.0;
  }

  /// Calcula o Resultado histórico acumulado para o DRE (Apenas Receitas e Despesas)
  Future<double> calcularResultadoAcumuladoAnteriorDRE({
    required String empresaId,
    required DateTime mesReferencia,
    required bool regimeCaixa,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final dataLimite = DateTime(
      mesReferencia.year,
      mesReferencia.month,
      0,
    ).toIso8601String().split('T')[0];
    final campoData = regimeCaixa ? 'data_pagamento' : 'data_competencia';

    final result = await db.rawQuery(
      '''
      SELECT c.grupo_dre, SUM(t.valor) as total
      FROM transacoes t
      INNER JOIN categorias c ON t.categoria_id = c.id
      WHERE t.empresa_id = ? AND t.$campoData <= ?
      GROUP BY c.grupo_dre
    ''',
      [empresaId, dataLimite],
    );

    double receitas = 0;
    double despesas = 0;

    for (var row in result) {
      final grupo = row['grupo_dre'] as String;
      final valor = (row['total'] as num).toDouble();
      if (grupo == 'RECEITA_BRUTA')
        receitas += valor;
      else
        despesas += valor;
    }
    return receitas - despesas;
  }

  // ==========================================
  // FUNÇÕES DE EDIÇÃO
  // ==========================================

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
