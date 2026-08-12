import 'package:flutter/material.dart';
import '../services/categoria_service.dart';
import '../app_state.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  final CategoriaService _categoriaService = CategoriaService();
  List<Map<String, dynamic>> _categorias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Adiciona listener para recarregar se a empresa mudar enquanto a tela estiver aberta
    AppState().empresaAtiva.addListener(_carregarCategorias);
    _carregarCategorias();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_carregarCategorias);
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    final empresaAtual = AppState().empresaAtiva.value;
    if (empresaAtual == null) return;

    setState(() => _isLoading = true);
    try {
      final dados = await _categoriaService.buscarCategorias(empresaAtual.id);
      setState(() {
        _categorias = dados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  String _formatarGrupoDre(String grupo) {
    switch (grupo) {
      case 'RECEITA_BRUTA':
        return 'Receita Bruta';
      case 'DEDUCAO':
        return 'Deduções/Impostos';
      case 'CUSTO_VARIAVEL':
        return 'Custos Variáveis';
      case 'DESPESA_FIXA':
        return 'Despesas Fixas';
      default:
        return grupo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de Contas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categorias.isEmpty
          ? const Center(
              child: Text('Nenhuma categoria cadastrada para esta empresa.'),
            )
          : ListView.builder(
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final bool isEntrada = cat['tipo'] == 'ENTRADA';
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: Icon(
                      isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isEntrada ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      cat['nome'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Grupo DRE: ${_formatarGrupoDre(cat['grupo_dre'])}',
                    ),
                    trailing: Chip(
                      label: Text(
                        cat['tipo'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: isEntrada ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
