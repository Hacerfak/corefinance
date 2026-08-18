import 'package:flutter/material.dart';
import '../services/categoria_service.dart';
import '../app_state.dart';

class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  final CategoriaService _categoriaService = CategoriaService();
  List<Map<String, dynamic>> _categorias = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_carregarCategorias);
    _carregarCategorias();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_carregarCategorias);
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) {
      if (mounted) setState(() => _categorias = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dados = await _categoriaService.buscarCategorias(empresa.id);
      setState(() {
        _categorias = dados;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirFormulario({Map<String, dynamic>? categoria}) {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    final nomeController = TextEditingController(text: categoria?['nome']);
    String tipoSelecionado = categoria?['tipo'] ?? 'SAIDA';

    // Fallback de retrocompatibilidade para abrir edição de categorias antigas
    String grupoSelecionado =
        categoria?['grupo_dre'] ?? 'DESPESA_ADMINISTRATIVA';
    if (grupoSelecionado == 'DEDUCAO') grupoSelecionado = 'DEDUCAO_RECEITA';
    if (grupoSelecionado == 'CUSTO_VARIAVEL') {
      grupoSelecionado = 'CUSTO_OPERACIONAL';
    }
    if (grupoSelecionado == 'DESPESA_FIXA') {
      grupoSelecionado = 'DESPESA_ADMINISTRATIVA';
    }

    final gruposDisponiveis = {
      'RECEITA_BRUTA': 'Receita Bruta de Serviços',
      'DEDUCAO_RECEITA': 'Deduções da Receita Bruta',
      'CUSTO_OPERACIONAL': 'Custo dos Serv. Prestados (CSP)',
      'DESPESA_COMERCIAL': 'Despesas Comerciais e Vendas',
      'DESPESA_ADMINISTRATIVA': 'Despesas Admin (Backoffice)',
      'DEPRECIACAO': 'Depreciação e Amortização',
      'RECEITA_FINANCEIRA': 'Receitas Financeiras',
      'DESPESA_FINANCEIRA': 'Despesas Financeiras',
      'IMPOSTO_LUCRO': 'Provisão de Impostos (IRPJ/CSLL)',
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: Text(
              categoria == null ? 'Nova Categoria' : 'Editar Categoria',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tipoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo (Entrada/Saída)',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ENTRADA',
                      child: Text('Entrada (Receita)'),
                    ),
                    DropdownMenuItem(
                      value: 'SAIDA',
                      child: Text('Saída (Despesa)'),
                    ),
                  ],
                  onChanged: (v) => setStateModal(() => tipoSelecionado = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: grupoSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Classificação no DRE',
                  ),
                  items: gruposDisponiveis.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setStateModal(() => grupoSelecionado = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Categoria',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nomeController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Informe o nome da categoria.'),
                      ),
                    );
                    return;
                  }
                  await _categoriaService.salvarCategoria(
                    id: categoria?['id'],
                    empresaId: empresa.id,
                    nome: nomeController.text,
                    grupoDre: grupoSelecionado,
                    tipo: tipoSelecionado,
                  );
                  if (mounted) Navigator.pop(context);
                  _carregarCategorias();
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatarGrupoDre(String grupo) {
    switch (grupo) {
      case 'RECEITA_BRUTA':
        return 'Receita Bruta de Serviços';
      case 'DEDUCAO':
      case 'DEDUCAO_RECEITA':
        return 'Deduções da Receita Bruta';
      case 'CUSTO_VARIAVEL':
      case 'CUSTO_OPERACIONAL':
        return 'Custo dos Serv. Prestados (CSP)';
      case 'DESPESA_COMERCIAL':
        return 'Despesas Comerciais e Vendas';
      case 'DESPESA_FIXA':
      case 'DESPESA_ADMINISTRATIVA':
        return 'Despesas Admin (Backoffice)';
      case 'DEPRECIACAO':
        return 'Depreciação e Amortização';
      case 'RECEITA_FINANCEIRA':
        return 'Receitas Financeiras';
      case 'DESPESA_FINANCEIRA':
        return 'Despesas Financeiras';
      case 'IMPOSTO_LUCRO':
        return 'Provisão de Impostos (IRPJ/CSLL)';
      default:
        return grupo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresa = AppState().empresaAtiva.value;

    return Scaffold(
      body: Column(
        children: [
          if (empresa == null)
            const Expanded(
              child: Center(
                child: Text(
                  'Selecione uma empresa no topo para gerenciar as categorias.',
                ),
              ),
            )
          else if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_categorias.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Nenhuma categoria cadastrada para esta empresa.'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
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
                        'DRE: ${_formatarGrupoDre(cat['grupo_dre'])}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _abrirFormulario(categoria: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _categoriaService.excluirCategoria(
                                cat['id'],
                              );
                              _carregarCategorias();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (AppState().empresaAtiva.value == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selecione uma empresa primeiro no topo.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          _abrirFormulario();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
