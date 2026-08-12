import 'package:supabase_flutter/supabase_flutter.dart';

class TransacaoService {
  final _supabase = Supabase.instance.client;

  /// Insere um novo lançamento manual no banco
  Future<void> criarLancamento({
    required String empresaId,
    required String descricao,
    required String tipo,
    required double valor,
    required String dataCompetencia,
    required String dataVencimento,
    String? dataPagamento,
  }) async {
    try {
      await _supabase.from('transacoes').insert({
        'empresa_id': empresaId,
        'descricao': descricao,
        'tipo': tipo,
        'valor': valor,
        'data_competencia': dataCompetencia,
        'data_vencimento': dataVencimento,
        'data_pagamento': dataPagamento,
      });
    } catch (e) {
      throw Exception('Erro ao salvar lançamento: $e');
    }
  }

  /// Insere múltiplos lançamentos (Parcelamento ou XML com faturas)
  Future<void> criarLancamentosEmLote(
    List<Map<String, dynamic>> lancamentos,
  ) async {
    try {
      await _supabase.from('transacoes').insert(lancamentos);
    } catch (e) {
      throw Exception('Erro ao salvar lote de lançamentos: $e');
    }
  }
}
