import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';

class EmpresaService {
  final _supabase = Supabase.instance.client;

  Future<void> carregarEmpresas() async {
    final response = await _supabase
        .from('empresas')
        .select()
        .order('nome_fantasia');
    final lista = (response as List).map((e) => Empresa.fromMap(e)).toList();

    AppState().empresasDisponiveis.value = lista;
    if (lista.isNotEmpty && AppState().empresaAtiva.value == null) {
      AppState().empresaAtiva.value =
          lista.first; // Seleciona a primeira por padrão
    }
  }

  Future<void> salvarEmpresa({
    String? id,
    required String nome,
    required String cnpj,
  }) async {
    final data = {'nome_fantasia': nome, 'cnpj': cnpj};
    if (id == null) {
      await _supabase.from('empresas').insert(data);
    } else {
      await _supabase.from('empresas').update(data).eq('id', id);
    }
    await carregarEmpresas(); // Atualiza a lista global após salvar
  }

  Future<void> excluirEmpresa(String id) async {
    await _supabase.from('empresas').delete().eq('id', id);
    await carregarEmpresas();
  }
}
