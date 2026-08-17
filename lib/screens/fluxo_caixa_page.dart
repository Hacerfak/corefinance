import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../services/parceiro_service.dart'; // <-- NOVO IMPORT
import '../app_state.dart';

class FluxoCaixaPage extends StatefulWidget {
  const FluxoCaixaPage({super.key});

  @override
  State<FluxoCaixaPage> createState() => _FluxoCaixaPageState();
}

class _FluxoCaixaPageState extends State<FluxoCaixaPage> {
  final TransacaoService _transacaoService = TransacaoService();
  final ParceiroService _parceiroService = ParceiroService(); // <-- NOVO

  bool _isLoading = false;
  DateTime _mesAtual = DateTime.now();

  List<Map<String, dynamic>> _parceiros = []; // <-- NOVO
  String? _filtroParceiro; // <-- NOVO

  double _entradasPagas = 0;
  double _entradasPendentes = 0;
  double _saidasPagas = 0;
  double _saidasPendentes = 0;
  double _ajustesPago = 0;
  double _ajustesPendente = 0;

  double _saldoAnteriorProjetado = 0;
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
      if (mounted)
        setState(() {
          _parceiros = [];
        });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final parcs = await _parceiroService.buscarParceiros(
        empresa.id,
      ); // <-- BUSCA PARCEIROS

      final dados = await _transacaoService.buscarLancamentos(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
        parceiroDoc: _filtroParceiro, // <-- APLICA FILTRO[cite: 5]
      );

      _saldoAnteriorProjetado = await _transacaoService
          .calcularSaldoAcumuladoAnterior(
            empresaId: empresa.id,
            mesReferencia: _mesAtual,
            campoData: 'data_vencimento',
            parceiroDoc: _filtroParceiro, // <-- APLICA FILTRO[cite: 5]
          );

      _entradasPagas = 0;
      _entradasPendentes = 0;
      _saidasPagas = 0;
      _saidasPendentes = 0;
      _ajustesPago = 0;
      _ajustesPendente = 0;
      _lancamentosPorDia = {};

      for (var item in dados) {
        final double valor = item['valor'];
        final String tipo = item['tipo'];
        final bool isPago = item['data_pagamento'] != null;
        final String vencimento = item['data_vencimento'];

        if (tipo == 'SALDO') {
          if (isPago) {
            _ajustesPago += valor;
          } else {
            _ajustesPendente += valor;
          }
        } else if (tipo == 'ENTRADA') {
          if (isPago) {
            _entradasPagas += valor;
          } else {
            _entradasPendentes += valor;
          }
        } else if (tipo == 'SAIDA') {
          if (isPago) {
            _saidasPagas += valor;
          } else {
            _saidasPendentes += valor;
          }
        }

        if (!_lancamentosPorDia.containsKey(vencimento)) {
          _lancamentosPorDia[vencimento] = [];
        }
        _lancamentosPorDia[vencimento]!.add(item);
      }

      setState(() {
        _parceiros = parcs; // <-- ATUALIZA TELA
        if (_filtroParceiro != null &&
            !_parceiros.any((p) => p['documento'] == _filtroParceiro)) {
          _filtroParceiro = null; // Limpa filtro
        }
      });
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
    final totalAjustes = _ajustesPago + _ajustesPendente;

    final variacaoMes = totalAjustes + totalEntradas - totalSaidas;
    final saldoFinalProjetado = _saldoAnteriorProjetado + variacaoMes;

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

        // NOVO: DROPDOWN DE FILTRO[cite: 5]
        if (_parceiros.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: DropdownButtonFormField<String>(
              value: _filtroParceiro,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Cliente / Fornecedor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_alt),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos os Parceiros'),
                ),
                ..._parceiros.map(
                  (p) => DropdownMenuItem<String>(
                    value: p['documento'],
                    child: Text(
                      '${p['nome']} (${p['documento']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _filtroParceiro = v);
                _gerarFluxo();
              },
            ),
          ),

        Expanded(
          child: empresa == null
              ? const Center(
                  child: Text('Selecione uma empresa no topo para visualizar.'),
                )
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
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
                                      'Saldo Inicial (Trazido)',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'R\$ ${_saldoAnteriorProjetado.toStringAsFixed(2)}',
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
                                      'Variação Prevista',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'R\$ ${variacaoMes.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: variacaoMes >= 0
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
                              'SALDO FINAL PROJETADO',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'R\$ ${saldoFinalProjetado.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: saldoFinalProjetado >= 0
                                    ? Colors.blue
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _CardResumo(
                                  titulo: 'Entradas (Mês)',
                                  valor: totalEntradas,
                                  cor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CardResumo(
                                  titulo: 'Saídas (Mês)',
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

                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: const Text(
                        'Agenda de Lançamentos:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    if (_lancamentosPorDia.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'Nenhuma previsão lançada para este mês.',
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
                            final isSaldo = item['tipo'] == 'SALDO';
                            final isPago = item['data_pagamento'] != null;

                            Color corLinha = isSaldo
                                ? Colors.blue
                                : (isEntrada ? Colors.green : Colors.red);

                            return ListTile(
                              leading: Icon(
                                isSaldo
                                    ? Icons.account_balance_wallet
                                    : (isEntrada
                                          ? Icons.arrow_circle_down
                                          : Icons.arrow_circle_up),
                                color: corLinha,
                              ),
                              title: Text(item['descricao']),
                              subtitle: Text(
                                isSaldo
                                    ? 'Ajuste de Saldo'
                                    : (item['categoria_nome'] ??
                                          'Sem Categoria'),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'R\$ ${item['valor'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: corLinha,
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
                          }),
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
  const _CardResumo({
    required this.titulo,
    required this.valor,
    required this.cor,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              titulo,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'R\$ ${valor.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
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
