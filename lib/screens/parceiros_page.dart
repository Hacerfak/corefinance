import 'package:flutter/material.dart';
import '../services/parceiro_service.dart';
import '../app_state.dart';

class ParceirosPage extends StatefulWidget {
  const ParceirosPage({super.key});

  @override
  State<ParceirosPage> createState() => _ParceirosPageState();
}

class _ParceirosPageState extends State<ParceirosPage> {
  final ParceiroService _parceiroService = ParceiroService();
  List<Map<String, dynamic>> _parceiros = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_carregarParceiros);
    _carregarParceiros();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_carregarParceiros);
    super.dispose();
  }

  Future<void> _carregarParceiros() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) {
      if (mounted) setState(() => _parceiros = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dados = await _parceiroService.buscarParceiros(empresa.id);
      setState(() => _parceiros = dados);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirFormulario({Map<String, dynamic>? parceiro}) {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    final nomeController = TextEditingController(text: parceiro?['nome']);
    final docController = TextEditingController(text: parceiro?['documento']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          parceiro == null ? 'Novo Cliente/Fornecedor' : 'Editar Parceiro',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Razão Social / Nome',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: docController,
              decoration: const InputDecoration(labelText: 'CNPJ / CPF'),
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
              if (nomeController.text.isEmpty || docController.text.isEmpty) {
                return;
              }
              await _parceiroService.salvarParceiro(
                id: parceiro?['id'],
                empresaId: empresa.id,
                documento: docController.text,
                nome: nomeController.text,
              );
              if (mounted) Navigator.pop(context);
              _carregarParceiros();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresa = AppState().empresaAtiva.value;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Row(
              children: [
                Icon(Icons.business_center, color: Colors.blueGrey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gerencie as empresas e pessoas que transacionam com você. Os parceiros também são criados automaticamente ao importar um XML (NFe/NFSe).',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: empresa == null
                ? const Center(child: Text('Selecione uma empresa no topo.'))
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _parceiros.isEmpty
                ? const Center(child: Text('Nenhum parceiro cadastrado.'))
                : ListView.builder(
                    itemCount: _parceiros.length,
                    itemBuilder: (context, index) {
                      final p = _parceiros[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.business,
                              color: Colors.blue,
                            ),
                          ),
                          title: Text(
                            p['nome'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('CNPJ/CPF: ${p['documento']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _abrirFormulario(parceiro: p),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await _parceiroService.excluirParceiro(
                                    p['id'],
                                  );
                                  _carregarParceiros();
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
                content: Text('Selecione uma empresa primeiro.'),
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
