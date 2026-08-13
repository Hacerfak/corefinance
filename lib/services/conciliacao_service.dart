import 'database_helper.dart';

class ConciliacaoService {
  Future<List<Map<String, dynamic>>> buscarSugestoes({
    required double valorOfx,
    required String dataOfx,
    required String empresaId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final tipo = valorOfx > 0 ? 'ENTRADA' : 'SAIDA';
    final valorAbsoluto = valorOfx.abs();

    final DateTime dataBase = DateTime.parse(dataOfx);
    final String dataMinima = dataBase
        .subtract(const Duration(days: 5))
        .toIso8601String()
        .split('T')[0];
    final String dataMaxima = dataBase
        .add(const Duration(days: 5))
        .toIso8601String()
        .split('T')[0];

    // Busca com rawQuery para pegar transações em aberto
    final result = await db.rawQuery(
      '''
      SELECT id, descricao, valor, data_vencimento
      FROM transacoes
      WHERE empresa_id = ? 
        AND tipo = ? 
        AND data_pagamento IS NULL
        AND data_vencimento >= ? 
        AND data_vencimento <= ?
    ''',
      [empresaId, tipo, dataMinima, dataMaxima],
    );

    List<Map<String, dynamic>> candidatos = List<Map<String, dynamic>>.from(
      result,
    );

    candidatos.sort((a, b) {
      double difValorA = (double.parse(a['valor'].toString()) - valorAbsoluto)
          .abs();
      double difValorB = (double.parse(b['valor'].toString()) - valorAbsoluto)
          .abs();
      if (difValorA != difValorB) return difValorA.compareTo(difValorB);

      DateTime dataA = DateTime.parse(a['data_vencimento']);
      DateTime dataB = DateTime.parse(b['data_vencimento']);
      int difDiasA = dataA.difference(dataBase).inDays.abs();
      int difDiasB = dataB.difference(dataBase).inDays.abs();
      return difDiasA.compareTo(difDiasB);
    });

    return candidatos;
  }

  Future<void> efetivarConciliacao(
    String transacaoId,
    String dataPagamentoBanco,
  ) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transacoes',
      {'data_pagamento': dataPagamentoBanco},
      where: 'id = ?',
      whereArgs: [transacaoId],
    );
  }
}
