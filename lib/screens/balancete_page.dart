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
  Map<String, List<Map<String, dynamic>>> _ajustesAgrupados = {};

  double _totalEntradas = 0;
  double _totalSaidas = 0;
  double _totalAjustes = 0;
  double _saldoAnterior = 0; // Novo

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
    if (empresa == null) return;

    setState(() => _isLoading = true);
    try {
      final dados = await _transacaoService.buscarBalancete(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
      );

      // Busca o histórico acumulado pago
      _saldoAnterior = await _transacaoService.calcularSaldoAcumuladoAnterior(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
        campoData: 'data_pagamento',
      );

      _entradasAgrupadas = {};
      _saidasAgrupadas = {};
      _ajustesAgrupados = {};
      _totalEntradas = 0;
      _totalSaidas = 0;
      _totalAjustes = 0;

      for (var item in dados) {
        String catNome = item['categoria_nome'] ?? 'Sem Categoria';
        double valor = item['valor'];
        String tipo = item['tipo'];

        if (tipo == 'SALDO') {
          _totalAjustes += valor;
          if (!_ajustesAgrupados.containsKey('Ajustes de Caixa'))
            _ajustesAgrupados['Ajustes de Caixa'] = [];
          _ajustesAgrupados['Ajustes de Caixa']!.add(item);
        } else if (tipo == 'ENTRADA') {
          _totalEntradas += valor;
          if (!_entradasAgrupadas.containsKey(catNome))
            _entradasAgrupadas[catNome] = [];
          _entradasAgrupadas[catNome]!.add(item);
        } else if (tipo == 'SAIDA') {
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
              fontSize: 18,
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

    // Matemática Financeira
    final resultadoMes = _totalAjustes + _totalEntradas - _totalSaidas;
    final saldoAcumuladoFinal = _saldoAnterior + resultadoMes;

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
              ? const Center(child: Text('Selecione uma empresa no topo.'))
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    // CARD DE PANORAMA GERAL
                    Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Saldo Anterior',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'R\$ ${_saldoAnterior.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  '+',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 24,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Resultado do Mês',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'R\$ ${resultadoMes.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: resultadoMes >= 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            const Text(
                              'SALDO FINAL ACUMULADO (EM CAIXA)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'R\$ ${saldoAcumuladoFinal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: saldoAcumuladoFinal >= 0
                                    ? Colors.blue
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_entradasAgrupadas.isEmpty &&
                        _saidasAgrupadas.isEmpty &&
                        _ajustesAgrupados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'Nenhuma conta paga registrada neste mês específico.',
                          ),
                        ),
                      ),

                    if (_ajustesAgrupados.isNotEmpty) ...[
                      _construirGrupo(
                        'SALDOS INICIAIS E AJUSTES',
                        _ajustesAgrupados,
                        Colors.blue,
                      ),
                      const Divider(),
                    ],
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
