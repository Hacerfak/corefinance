import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../app_state.dart';

class FluxoCaixaPage extends StatefulWidget {
  const FluxoCaixaPage({super.key});

  @override
  State<FluxoCaixaPage> createState() => _FluxoCaixaPageState();
}

class _FluxoCaixaPageState extends State<FluxoCaixaPage> {
  final TransacaoService _transacaoService = TransacaoService();

  bool _isLoading = false;
  DateTime _mesAtual = DateTime.now();

  double _entradasPagas = 0;
  double _entradasPendentes = 0;
  double _saidasPagas = 0;
  double _saidasPendentes = 0;
  Map<String, List<Map<String, dynamic>>> _lancamentosPorDia = {};

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_gerarFluxo);
    _gerarFluxo();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_gerarFluxo);
    super.dispose();
  }

  Future<void> _gerarFluxo() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) {
      if (mounted) setState(() => _lancamentosPorDia = {});
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dados = await _transacaoService.buscarLancamentos(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
      );

      _entradasPagas = 0;
      _entradasPendentes = 0;
      _saidasPagas = 0;
      _saidasPendentes = 0;
      _lancamentosPorDia = {};

      for (var item in dados) {
        final double valor = item['valor'];
        final bool isEntrada = item['tipo'] == 'ENTRADA';
        final bool isPago = item['data_pagamento'] != null;
        final String vencimento = item['data_vencimento'];

        if (isEntrada) {
          if (isPago)
            _entradasPagas += valor;
          else
            _entradasPendentes += valor;
        } else {
          if (isPago)
            _saidasPagas += valor;
          else
            _saidasPendentes += valor;
        }

        if (!_lancamentosPorDia.containsKey(vencimento))
          _lancamentosPorDia[vencimento] = [];
        _lancamentosPorDia[vencimento]!.add(item);
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
      _gerarFluxo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);

    final totalEntradas = _entradasPagas + _entradasPendentes;
    final totalSaidas = _saidasPagas + _saidasPendentes;
    final saldoProjetado = totalEntradas - totalSaidas;
    final diasOrdenados = _lancamentosPorDia.keys.toList()..sort();
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
                    'Selecione uma empresa no topo para visualizar o fluxo.',
                  ),
                )
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _lancamentosPorDia.isEmpty
              ? const Center(child: Text('Nenhuma previsão para este mês.'))
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _CardResumo(
                            titulo: 'Saldo Projetado do Mês',
                            valor: saldoProjetado,
                            cor: saldoProjetado >= 0
                                ? Colors.green
                                : Colors.red,
                            destaque: true,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _CardResumo(
                                  titulo: 'Entradas Totais',
                                  valor: totalEntradas,
                                  cor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CardResumo(
                                  titulo: 'Saídas Totais',
                                  valor: totalSaidas,
                                  cor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _CardDetalhe(
                                  'Recebido',
                                  _entradasPagas,
                                  'A Receber',
                                  _entradasPendentes,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CardDetalhe(
                                  'Pago',
                                  _saidasPagas,
                                  'A Pagar',
                                  _saidasPendentes,
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: const Text(
                        'Lançamentos por Data de Vencimento:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...diasOrdenados.map((dia) {
                      final itensDoDia = _lancamentosPorDia[dia]!;
                      final dataExibicao = DateFormat(
                        'dd/MM/yyyy',
                      ).format(DateTime.parse(dia));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            color: Colors.grey.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              dataExibicao,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          ...itensDoDia.map((item) {
                            final isEntrada = item['tipo'] == 'ENTRADA';
                            final isPago = item['data_pagamento'] != null;
                            return ListTile(
                              leading: Icon(
                                isEntrada
                                    ? Icons.arrow_circle_down
                                    : Icons.arrow_circle_up,
                                color: isEntrada ? Colors.green : Colors.red,
                              ),
                              title: Text(item['descricao']),
                              subtitle: Text(
                                item['categoria_nome'] ?? 'Sem Categoria',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'R\$ ${item['valor'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isEntrada
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPago
                                          ? Colors.green
                                          : Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPago ? 'REALIZADO' : 'PENDENTE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CardResumo extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color cor;
  final bool destaque;
  const _CardResumo({
    required this.titulo,
    required this.valor,
    required this.cor,
    this.destaque = false,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: destaque ? 4 : 1,
      color: destaque ? cor.withValues(alpha: 0.1) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: destaque ? 16 : 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'R\$ ${valor.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: destaque ? 28 : 20,
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

class _CardDetalhe extends StatelessWidget {
  final String label1;
  final double valor1;
  final String label2;
  final double valor2;
  final Color cor;
  const _CardDetalhe(
    this.label1,
    this.valor1,
    this.label2,
    this.valor2,
    this.cor,
  );
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label1, style: const TextStyle(fontSize: 12)),
                Text(
                  'R\$ ${valor1.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label2, style: const TextStyle(fontSize: 12)),
                Text(
                  'R\$ ${valor2.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
