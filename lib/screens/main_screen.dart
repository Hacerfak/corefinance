import 'package:flutter/material.dart';
import 'conciliacao_ofx_page.dart';
import 'lancamento_manual_page.dart';
import 'categorias_page.dart';
import 'gerenciar_empresas_page.dart';
import 'backup_page.dart';
import '../services/empresa_service.dart';
import 'gestao_lancamentos_page.dart';
import 'balancete_page.dart';
import 'fluxo_caixa_page.dart';
import 'dashboard_page.dart';
import '../app_state.dart';
import 'dre_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _indiceAtual = 0;

  @override
  void initState() {
    super.initState();
    // Apenas carrega a lista de empresas em background para as outras telas usarem nos Dropdowns
    EmpresaService().carregarEmpresas();
  }

  // Lista de telas reorganizada
  late final List<Widget> _telas = [
    const DashboardPage(),
    LancamentoManualPage(
      onVoltarDashboard: () {
        setState(() {
          _indiceAtual = 0; // Volta para o Dashboard
        });
      },
    ),
    const ConciliacaoOfxPage(),
    const GestaoLancamentosPage(),
    const BalancetePage(),
    const FluxoCaixaPage(),
    const DrePage(),
    const GerenciarEmpresasPage(),
    const CategoriasPage(),
    const BackupPage(),
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
        title: ValueListenableBuilder<List<Empresa>>(
          valueListenable: AppState().empresasDisponiveis,
          builder: (context, empresas, child) {
            if (empresas.isEmpty) return const Text('CoreFinance');

            return ValueListenableBuilder<Empresa?>(
              valueListenable: AppState().empresaAtiva,
              builder: (context, empresaAtiva, child) {
                return DropdownButtonHideUnderline(
                  child: DropdownButton<Empresa>(
                    value: empresaAtiva,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    dropdownColor: Theme.of(context).colorScheme.primary,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    items: empresas
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.nomeFantasia),
                          ),
                        )
                        .toList(),
                    onChanged: (novaEmpresa) {
                      if (novaEmpresa != null) {
                        AppState().empresaAtiva.value = novaEmpresa;
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'CoreFinance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Controle Inteligente',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
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
              leading: const Icon(
                Icons.add_circle_outline,
                color: Colors.green,
              ),
              title: const Text(
                'Novo Lançamento',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Manual ou via XML'),
              selected: _indiceAtual == 1,
              onTap: () => _aoSelecionarMenu(1),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Conciliação OFX'),
              selected: _indiceAtual == 2,
              onTap: () => _aoSelecionarMenu(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Gestão de contas'),
              selected: _indiceAtual == 3,
              onTap: () => _aoSelecionarMenu(3),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Balancete'),
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
              selected: _indiceAtual == 7,
              onTap: () => _aoSelecionarMenu(7),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Plano de Contas'),
              selected: _indiceAtual == 8,
              onTap: () => _aoSelecionarMenu(8),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync, color: Colors.blue),
              title: const Text('Nuvem e Backup'),
              selected: _indiceAtual == 9,
              onTap: () => _aoSelecionarMenu(9),
            ),
          ],
        ),
      ),
      body: _telas[_indiceAtual],
    );
  }
}
