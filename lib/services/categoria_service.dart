import 'package:supabase_flutter/supabase_flutter.dart';

class CategoriaService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> buscarCategorias(String empresaId) async {
    try {
      final response = await _supabase
          .from('categorias')
          .select()
          .eq('empresa_id', empresaId)
          .order('tipo', ascending: true)
          .order('grupo_dre', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao buscar categorias: $e');
    }
  }

  Future<void> salvarCategoria({
    String? id,
    required String empresaId,
    required String nome,
    required String grupoDre,
    required String tipo,
  }) async {
    try {
      final data = {
        'empresa_id': empresaId,
        'nome': nome,
        'grupo_dre': grupoDre,
        'tipo': tipo,
      };

      if (id == null) {
        await _supabase.from('categorias').insert(data);
      } else {
        await _supabase.from('categorias').update(data).eq('id', id);
      }
    } catch (e) {
      throw Exception('Erro ao salvar categoria: $e');
    }
  }

  Future<void> excluirCategoria(String id) async {
    try {
      await _supabase.from('categorias').delete().eq('id', id);
    } catch (e) {
      throw Exception(
        'Erro ao excluir categoria (Verifique se há lançamentos vinculados): $e',
      );
    }
  }
}
