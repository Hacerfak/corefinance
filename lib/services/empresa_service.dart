import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import '../app_state.dart';

class EmpresaService {
  final _uuid = const Uuid();

  Future<void> carregarEmpresas() async {
    final db = await DatabaseHelper.instance.database;
    final response = await db.query('empresas', orderBy: 'nome_fantasia');

    final lista = response.map((e) => Empresa.fromMap(e)).toList();
    AppState().empresasDisponiveis.value = lista;

    // Auto-seleciona a primeira empresa se houver alguma e nenhuma estiver ativa
    if (lista.isNotEmpty && AppState().empresaAtiva.value == null) {
      AppState().empresaAtiva.value = lista.first;
    } else if (lista.isEmpty) {
      AppState().empresaAtiva.value = null;
    }
  }

  // ... (mantenha o resto das funções salvarEmpresa e excluirEmpresa como estão)
  Future<void> salvarEmpresa({
    String? id,
    required String nome,
    required String cnpj,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final data = {
      'nome_fantasia': nome,
      'cnpj': cnpj,
      'created_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      data['id'] = _uuid.v4();
      await db.insert('empresas', data);
    } else {
      await db.update('empresas', data, where: 'id = ?', whereArgs: [id]);
    }
    await carregarEmpresas();
  }

  Future<void> excluirEmpresa(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('empresas', where: 'id = ?', whereArgs: [id]);

    // Se excluiu a empresa que estava ativa, limpa a seleção
    if (AppState().empresaAtiva.value?.id == id) {
      AppState().empresaAtiva.value = null;
    }
    await carregarEmpresas();
  }
}
