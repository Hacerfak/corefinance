import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../app_state.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TransacaoService _transacaoService = TransacaoService();

  bool _isLoading = false;
  DateTime _mesAtual = DateTime.now();

  double _receitasRealizadas = 0;
  double _despesasRealizadas = 0;
  double _saldoAjustes = 0; // Nova variável para saldos iniciais/ajustes

  double _aReceber = 0;
  double _aPagar = 0;
  List<Map<String, dynamic>> _ultimosLancamentos = [];

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_carregarDashboard);
    _carregarDashboard();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_carregarDashboard);
    super.dispose();
  }

  Future<void> _carregarDashboard() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) {
      if (mounted) {
        setState(() {
          _receitasRealizadas = 0;
          _despesasRealizadas = 0;
          _saldoAjustes = 0;
          _aReceber = 0;
          _aPagar = 0;
          _ultimosLancamentos = [];
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dados = await _transacaoService.buscarLancamentos(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
      );

      _receitasRealizadas = 0;
      _despesasRealizadas = 0;
      _saldoAjustes = 0;
      _aReceber = 0;
      _aPagar = 0;

      for (var item in dados) {
        final double valor = item['valor'];
        final String tipo = item['tipo'];
        final bool isPago = item['data_pagamento'] != null;

        if (tipo == 'SALDO') {
          if (isPago) _saldoAjustes += valor;
        } else if (tipo == 'ENTRADA') {
          if (isPago)
            _receitasRealizadas += valor;
          else
            _aReceber += valor;
        } else if (tipo == 'SAIDA') {
          if (isPago)
            _despesasRealizadas += valor;
          else
            _aPagar += valor;
        }
      }

      _ultimosLancamentos = dados.take(5).toList();
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
      _carregarDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);

    // O Saldo Atual agora soma os Ajustes de Caixa (Saldos Iniciais)
    final saldoAtual =
        _saldoAjustes + _receitasRealizadas - _despesasRealizadas;

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
                  child: Text(
                    'Selecione uma empresa no topo para visualizar o Dashboard.',
                  ),
                )
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregarDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Card(
                        elevation: 4,
                        color: saldoAtual >= 0
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24.0,
                            horizontal: 16.0,
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Saldo Atual (Mês Realizado)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'R\$ ${saldoAtual.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: saldoAtual >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              if (_saldoAjustes != 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '(Inclui R\$ ${_saldoAjustes.toStringAsFixed(2)} de Ajustes/Saldo Inicial)',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _IndicadorCard(
                              titulo: 'Receitas (Pagas)',
                              valor: _receitasRealizadas,
                              cor: Colors.green,
                              icone: Icons.arrow_downward,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _IndicadorCard(
                              titulo: 'Despesas (Pagas)',
                              valor: _despesasRealizadas,
                              cor: Colors.red,
                              icone: Icons.arrow_upward,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _IndicadorCard(
                              titulo: 'A Receber',
                              valor: _aReceber,
                              cor: Colors.blue,
                              icone: Icons.schedule,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _IndicadorCard(
                              titulo: 'A Pagar',
                              valor: _aPagar,
                              cor: Colors.orange,
                              icone: Icons.warning_amber_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Lançamentos Recentes:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_ultimosLancamentos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Nenhum lançamento encontrado neste mês.',
                          ),
                        )
                      else
                        ..._ultimosLancamentos.map((item) {
                          final isEntrada = item['tipo'] == 'ENTRADA';
                          final isSaldo = item['tipo'] == 'SALDO';
                          final isPago = item['data_pagamento'] != null;

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: isSaldo
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : (isPago
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.orange.withValues(
                                              alpha: 0.1,
                                            )),
                                child: Icon(
                                  isSaldo
                                      ? Icons.account_balance_wallet
                                      : (isEntrada ? Icons.add : Icons.remove),
                                  color: isSaldo
                                      ? Colors.blue
                                      : (isPago ? Colors.green : Colors.orange),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item['descricao'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                isSaldo
                                    ? 'Ajuste de Caixa'
                                    : (isPago ? 'Pago' : 'Pendente'),
                                style: TextStyle(
                                  color: isSaldo
                                      ? Colors.blue
                                      : (isPago ? Colors.green : Colors.orange),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                'R\$ ${item['valor'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSaldo
                                      ? Colors.blue
                                      : (isEntrada ? Colors.green : Colors.red),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _IndicadorCard extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;
  const _IndicadorCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: cor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'R\$ ${valor.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
