import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class ConciliacaoService {
  /// Salva os extratos garantindo que não existam linhas duplicadas (conflictAlgorithm)
  Future<void> salvarTransacoesBancarias(
    String empresaId,
    List<Map<String, dynamic>> transacoes,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();

    for (var t in transacoes) {
      batch.insert('transacoes_bancarias', {
        'id': const Uuid().v4(),
        'empresa_id': empresaId,
        'fitid': t['fitid'],
        'data': t['data'],
        'valor': t['valor'],
        'descricao': t['descricao'],
        'contraparte_documento': t['contraparte_documento'], // <-- ADICIONADO
        'tipo': t['tipo'],
        'conciliado': 0,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
  }

  /// Lista o histórico de transações que vieram pelo OFX no mês
  Future<List<Map<String, dynamic>>> buscarTransacoesBancarias(
    String empresaId,
    DateTime mesReferencia,
  ) async {
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

    return await db.query(
      'transacoes_bancarias',
      where: 'empresa_id = ? AND data >= ? AND data <= ?',
      whereArgs: [empresaId, dataInicio, dataFim],
      orderBy: 'data DESC',
    );
  }

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

  /// Conecta um lançamento do sistema à linha do OFX e marca como pago
  Future<void> efetivarConciliacao(
    String transacaoBancoId,
    String transacaoSistemaId,
    String dataPagamentoBanco,
  ) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'transacoes',
        {'data_pagamento': dataPagamentoBanco},
        where: 'id = ?',
        whereArgs: [transacaoSistemaId],
      );
      await txn.update(
        'transacoes_bancarias',
        {'conciliado': 1, 'transacao_sistema_id': transacaoSistemaId},
        where: 'id = ?',
        whereArgs: [transacaoBancoId],
      );
    });
  }

  /// Cria um lançamento direto da informação do OFX
  Future<void> criarLancamentoDoOfx(
    String transacaoBancoId,
    Map<String, dynamic> novaTransacao,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final id = const Uuid().v4();
    novaTransacao['id'] = id;
    novaTransacao['created_at'] = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('transacoes', novaTransacao);
      await txn.update(
        'transacoes_bancarias',
        {'conciliado': 1, 'transacao_sistema_id': id},
        where: 'id = ?',
        whereArgs: [transacaoBancoId],
      );
    });
  }

  /// Apenas oculta o OFX (Marcado como ignorado)
  Future<void> ignorarTransacao(String transacaoBancoId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transacoes_bancarias',
      {'conciliado': 1, 'transacao_sistema_id': null},
      where: 'id = ?',
      whereArgs: [transacaoBancoId],
    );
  }

  /// Desfaz o processo: Remove o status de pago do sistema e "desigona" o OFX
  Future<void> desfazerConciliacao(String transacaoBancoId) async {
    final db = await DatabaseHelper.instance.database;
    final tb = await db.query(
      'transacoes_bancarias',
      where: 'id = ?',
      whereArgs: [transacaoBancoId],
    );

    if (tb.isNotEmpty) {
      final sysId = tb.first['transacao_sistema_id'] as String?;
      await db.transaction((txn) async {
        if (sysId != null) {
          // Remove a data de pagamento da transação original
          await txn.update(
            'transacoes',
            {'data_pagamento': null},
            where: 'id = ?',
            whereArgs: [sysId],
          );
        }
        // Desmarca a linha do banco
        await txn.update(
          'transacoes_bancarias',
          {'conciliado': 0, 'transacao_sistema_id': null},
          where: 'id = ?',
          whereArgs: [transacaoBancoId],
        );
      });
    }
  }
}
