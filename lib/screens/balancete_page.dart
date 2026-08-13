import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../app_state.dart';

class BalancetePage extends StatefulWidget {
  const BalancetePage({super.key});

  @override
  State<BalancetePage> createState() => _BalancetePageState();
}

class _BalancetePageState extends State<BalancetePage> {
  final TransacaoService _transacaoService = TransacaoService();

  bool _isLoading = false;
  DateTime _mesAtual = DateTime.now();

  Map<String, List<Map<String, dynamic>>> _entradasAgrupadas = {};
  Map<String, List<Map<String, dynamic>>> _saidasAgrupadas = {};
  double _totalEntradas = 0;
  double _totalSaidas = 0;

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_gerarRelatorio);
    _gerarRelatorio();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_gerarRelatorio);
    super.dispose();
  }

  Future<void> _gerarRelatorio() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) {
      if (mounted) {
        setState(() {
          _entradasAgrupadas = {};
          _saidasAgrupadas = {};
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dados = await _transacaoService.buscarBalancete(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
      );

      _entradasAgrupadas = {};
      _saidasAgrupadas = {};
      _totalEntradas = 0;
      _totalSaidas = 0;

      for (var item in dados) {
        String catNome = item['categoria_nome'] ?? 'Sem Categoria';
        double valor = item['valor'];
        if (item['tipo'] == 'ENTRADA') {
          _totalEntradas += valor;
          if (!_entradasAgrupadas.containsKey(catNome))
            _entradasAgrupadas[catNome] = [];
          _entradasAgrupadas[catNome]!.add(item);
        } else {
          _totalSaidas += valor;
          if (!_saidasAgrupadas.containsKey(catNome))
            _saidasAgrupadas[catNome] = [];
          _saidasAgrupadas[catNome]!.add(item);
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mudarMes(int incremento) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + incremento, 1);
      _gerarRelatorio();
    });
  }

  Widget _construirGrupo(
    String titulo,
    Map<String, List<Map<String, dynamic>>> dados,
    Color corBase,
  ) {
    if (dados.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: corBase,
            ),
          ),
        ),
        ...dados.entries.map((entry) {
          String categoria = entry.key;
          List<Map<String, dynamic>> itens = entry.value;
          double totalCategoria = itens.fold(
            0,
            (sum, item) => sum + item['valor'],
          );
          return ExpansionTile(
            title: Text(
              categoria,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Text(
              'R\$ ${totalCategoria.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: corBase,
                fontSize: 16,
              ),
            ),
            children: itens.map((item) {
              return ListTile(
                title: Text(item['descricao']),
                subtitle: Text(
                  'Data Pag: ${item['data_pagamento'].toString().substring(8, 10)}/${item['data_pagamento'].toString().substring(5, 7)}' +
                      (item['documento'] != null
                          ? ' | Doc: ${item['documento']}'
                          : ''),
                ),
                trailing: Text(
                  'R\$ ${item['valor'].toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);
    final saldo = _totalEntradas - _totalSaidas;
    final empresa = AppState().empresaAtiva.value;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _mudarMes(-1),
              ),
              Text(
                mesCapitalizado,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _mudarMes(1),
              ),
            ],
          ),
        ),

        Expanded(
          child: empresa == null
              ? const Center(
                  child: Text('Selecione uma empresa no topo para visualizar.'),
                )
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _entradasAgrupadas.isEmpty && _saidasAgrupadas.isEmpty
              ? const Center(
                  child: Text('Nenhuma conta PAGA registrada neste mês.'),
                )
              : ListView(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(16),
                      color: saldo >= 0
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Saldo Mensal do Caixa',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'R\$ ${saldo.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: saldo >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _construirGrupo(
                      'ENTRADAS (RECEITAS)',
                      _entradasAgrupadas,
                      Colors.green,
                    ),
                    const Divider(),
                    _construirGrupo(
                      'SAÍDAS (DESPESAS)',
                      _saidasAgrupadas,
                      Colors.red,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
