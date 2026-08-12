import 'package:flutter/material.dart';
import 'import_xml_page.dart';
import 'conciliacao_ofx_page.dart';
import 'lancamento_manual_page.dart';
import 'configuracoes_page.dart';
import '../app_state.dart';
import '../services/empresa_service.dart';
import 'gerenciar_empresas_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    EmpresaService().carregarEmpresas(); // Carrega as empresas ao abrir o app
  }

  int _indiceAtual = 0;

  // Lista de telas atualizada com todas as implementações
  final List<Widget> _telas = [
    const Center(
      child: Text(
        'Tela do Dashboard (Em construção)',
        style: TextStyle(fontSize: 24),
      ),
    ),
    const ImportXmlPage(),
    const ConciliacaoOfxPage(),
    const LancamentoManualPage(),
    const Center(
      child: Text(
        'Tela de Balancete (Em construção)',
        style: TextStyle(fontSize: 24),
      ),
    ),
    const Center(
      child: Text(
        'Tela de Fluxo de Caixa (Em construção)',
        style: TextStyle(fontSize: 24),
      ),
    ),
    const Center(
      child: Text(
        'Tela de DRE (Em construção)',
        style: TextStyle(fontSize: 24),
      ),
    ),
    const ConfiguracoesPage(),
  ];

  void _aoSelecionarMenu(int index) {
    setState(() {
      _indiceAtual = index;
    });
    Navigator.pop(context); // Fecha o menu lateral no mobile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Título reativo: muda automaticamente quando a empresa muda!
        title: ValueListenableBuilder<Empresa?>(
          valueListenable: AppState().empresaAtiva,
          builder: (context, empresa, child) {
            return Text(
              'CoreFinance - ${empresa?.nomeFantasia ?? 'Carregando...'}',
              style: const TextStyle(fontSize: 16),
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  // Seletor de Empresas
                  ValueListenableBuilder<List<Empresa>>(
                    valueListenable: AppState().empresasDisponiveis,
                    builder: (context, empresas, child) {
                      return DropdownButton<Empresa>(
                        isExpanded: true,
                        dropdownColor: Theme.of(context).colorScheme.primary,
                        value: AppState().empresaAtiva.value,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                        ),
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        onChanged: (Empresa? novaEmpresa) {
                          if (novaEmpresa != null) {
                            AppState().empresaAtiva.value = novaEmpresa;
                          }
                        },
                        items: empresas.map<DropdownMenuItem<Empresa>>((
                          Empresa emp,
                        ) {
                          return DropdownMenuItem<Empresa>(
                            value: emp,
                            child: Text(emp.nomeFantasia),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _indiceAtual == 0,
              onTap: () => _aoSelecionarMenu(0),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Importar XML (NFe)'),
              selected: _indiceAtual == 1,
              onTap: () => _aoSelecionarMenu(1),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Conciliação OFX'),
              selected: _indiceAtual == 2,
              onTap: () => _aoSelecionarMenu(2),
            ),
            ListTile(
              leading: const Icon(Icons.add_card),
              title: const Text('Lançamento Manual'),
              selected: _indiceAtual == 3,
              onTap: () => _aoSelecionarMenu(3),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Balancete (Lançamentos)'),
              selected: _indiceAtual == 4,
              onTap: () => _aoSelecionarMenu(4),
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Fluxo de Caixa'),
              selected: _indiceAtual == 5,
              onTap: () => _aoSelecionarMenu(5),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('DRE (Resultados)'),
              selected: _indiceAtual == 6,
              onTap: () => _aoSelecionarMenu(6),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.domain),
              title: const Text('Gerenciar Empresas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GerenciarEmpresasPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configurações'),
              selected: _indiceAtual == 7,
              onTap: () => _aoSelecionarMenu(7),
            ),
          ],
        ),
      ),
      body: _telas[_indiceAtual],
    );
  }
}
