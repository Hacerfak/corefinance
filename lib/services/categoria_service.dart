import 'package:supabase_flutter/supabase_flutter.dart';

class CategoriaService {
  final _supabase = Supabase.instance.client;

  /// Busca todas as categorias de uma empresa
  Future<List<Map<String, dynamic>>> buscarCategorias(String empresaId) async {
    try {
      final response = await _supabase
          .from('categorias')
          .select()
          .eq('empresa_id', empresaId)
          .order('tipo', ascending: true) // Agrupa entradas e saídas
          .order('grupo_dre', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao buscar categorias: $e');
    }
  }

  /// Adiciona uma nova categoria manualmente
  Future<void> criarCategoria({
    required String empresaId,
    required String nome,
    required String grupoDre,
    required String tipo,
  }) async {
    try {
      await _supabase.from('categorias').insert({
        'empresa_id': empresaId,
        'nome': nome,
        'grupo_dre': grupoDre,
        'tipo': tipo,
      });
    } catch (e) {
      throw Exception('Erro ao criar categoria: $e');
    }
  }
}
