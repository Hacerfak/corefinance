import 'package:supabase_flutter/supabase_flutter.dart';

class ConciliacaoService {
  final _supabase = Supabase.instance.client;

  /// Busca lançamentos abertos no Supabase e os ordena por probabilidade
  Future<List<Map<String, dynamic>>> buscarSugestoes({
    required double valorOfx,
    required String dataOfx, // Formato YYYY-MM-DD
    required String empresaId,
  }) async {
    // 1. Identifica se o banco registrou Entrada (+) ou Saída (-)
    final tipo = valorOfx > 0 ? 'ENTRADA' : 'SAIDA';
    final valorAbsoluto = valorOfx.abs();

    // 2. Cria uma "janela" de tolerância de 5 dias para compensação bancária
    final DateTime dataBase = DateTime.parse(dataOfx);
    final String dataMinima = dataBase
        .subtract(const Duration(days: 5))
        .toIso8601String()
        .split('T')[0];
    final String dataMaxima = dataBase
        .add(const Duration(days: 5))
        .toIso8601String()
        .split('T')[0];

    try {
      // 3. Busca no banco de dados apenas lançamentos em aberto (data_pagamento nula)
      final response = await _supabase
          .from('transacoes')
          .select('''
            id, 
            descricao, 
            valor, 
            data_vencimento,
            pessoas (nome)
          ''')
          .eq('empresa_id', empresaId)
          .eq('tipo', tipo)
          .isFilter('data_pagamento', null) // SÓ OS EM ABERTO
          .gte('data_vencimento', dataMinima)
          .lte('data_vencimento', dataMaxima);

      List<Map<String, dynamic>> candidatos = List<Map<String, dynamic>>.from(
        response,
      );

      // 4. O Algoritmo de "Match" (Ordenação Inteligente)
      candidatos.sort((a, b) {
        // Primeiro critério: Menor diferença de valor
        double difValorA = (double.parse(a['valor'].toString()) - valorAbsoluto)
            .abs();
        double difValorB = (double.parse(b['valor'].toString()) - valorAbsoluto)
            .abs();

        if (difValorA != difValorB) {
          return difValorA.compareTo(difValorB);
        }

        // Segundo critério (Desempate): Proximidade da data
        DateTime dataA = DateTime.parse(a['data_vencimento']);
        DateTime dataB = DateTime.parse(b['data_vencimento']);
        int difDiasA = dataA.difference(dataBase).inDays.abs();
        int difDiasB = dataB.difference(dataBase).inDays.abs();

        return difDiasA.compareTo(difDiasB);
      });

      return candidatos;
    } catch (e) {
      print('Erro ao buscar sugestões: $e');
      return [];
    }
  }

  /// Atualiza o banco, "baixando" o título e efetivando a conciliação
  Future<void> efetivarConciliacao(
    String transacaoId,
    String dataPagamentoBanco,
  ) async {
    await _supabase
        .from('transacoes')
        .update({'data_pagamento': dataPagamentoBanco})
        .eq('id', transacaoId);
  }
}
