import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/empresa_service.dart';

class GerenciarEmpresasPage extends StatefulWidget {
  const GerenciarEmpresasPage({super.key});

  @override
  State<GerenciarEmpresasPage> createState() => _GerenciarEmpresasPageState();
}

class _GerenciarEmpresasPageState extends State<GerenciarEmpresasPage> {
  final EmpresaService _empresaService = EmpresaService();

  void _abrirFormulario({Empresa? empresa}) {
    final nomeController = TextEditingController(text: empresa?.nomeFantasia);
    final cnpjController = TextEditingController(text: empresa?.cnpj);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(empresa == null ? 'Nova Empresa' : 'Editar Empresa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome Fantasia'),
            ),
            TextField(
              controller: cnpjController,
              decoration: const InputDecoration(
                labelText: 'CNPJ (Somente números)',
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
              await _empresaService.salvarEmpresa(
                id: empresa?.id,
                nome: nomeController.text,
                cnpj: cnpjController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Empresas')),
      body: ValueListenableBuilder<List<Empresa>>(
        valueListenable: AppState().empresasDisponiveis,
        builder: (context, empresas, child) {
          if (empresas.isEmpty) {
            return const Center(child: Text('Nenhuma empresa cadastrada.'));
          }
          return ListView.builder(
            itemCount: empresas.length,
            itemBuilder: (context, index) {
              final emp = empresas[index];
              return ListTile(
                title: Text(emp.nomeFantasia),
                subtitle: Text('CNPJ: ${emp.cnpj}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _abrirFormulario(empresa: emp),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _empresaService.excluirEmpresa(emp.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
