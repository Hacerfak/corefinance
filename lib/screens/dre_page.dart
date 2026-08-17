import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../app_state.dart';

class DrePage extends StatefulWidget {
  const DrePage({super.key});

  @override
  State<DrePage> createState() => _DrePageState();
}

class _DrePageState extends State<DrePage> {
  final TransacaoService _transacaoService = TransacaoService();
  bool _isLoading = false;
  DateTime _mesAtual = DateTime.now();

  bool _isRegimeCaixa = false;
  double _receitaBruta = 0;
  double _deducoes = 0;
  double _custosVariaveis = 0;
  double _despesasFixas = 0;
  double _resultadoAnteriorAcumulado = 0;

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_gerarDre);
    _gerarDre();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_gerarDre);
    super.dispose();
  }

  Future<void> _gerarDre() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    setState(() => _isLoading = true);
    try {
      final dados = await _transacaoService.buscarDRE(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
        regimeCaixa: _isRegimeCaixa,
      );

      _resultadoAnteriorAcumulado = await _transacaoService
          .calcularResultadoAcumuladoAnteriorDRE(
            empresaId: empresa.id,
            mesReferencia: _mesAtual,
            regimeCaixa: _isRegimeCaixa,
          );

      _receitaBruta = 0;
      _deducoes = 0;
      _custosVariaveis = 0;
      _despesasFixas = 0;

      for (var item in dados) {
        final double valor = item['valor'];
        final String grupo = item['grupo_dre'] ?? '';

        if (grupo == 'RECEITA_BRUTA') {
          _receitaBruta += valor;
        } else if (grupo == 'DEDUCAO') {
          _deducoes += valor;
        } else if (grupo == 'CUSTO_VARIAVEL') {
          _custosVariaveis += valor;
        } else if (grupo == 'DESPESA_FIXA') {
          _despesasFixas += valor;
        }
      }
      setState(() {});
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
      _gerarDre();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);

    final empresa = AppState().empresaAtiva.value;

    final receitaLiquida = _receitaBruta - _deducoes;
    final margemContribuicao = receitaLiquida - _custosVariaveis;
    final resultadoLiquido = margemContribuicao - _despesasFixas;

    final margemLucro = _receitaBruta > 0
        ? (resultadoLiquido / _receitaBruta) * 100
        : 0.0;

    // NOVO: Cálculo do Percentual da Margem de Contribuição (sobre a Receita Líquida)
    final percentualMargemContribuicao = receitaLiquida > 0
        ? (margemContribuicao / receitaLiquida) * 100
        : 0.0;

    // Matemática final acumulada
    final resultadoFinalHistorico =
        _resultadoAnteriorAcumulado + resultadoLiquido;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              Row(
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
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Competência'),
                    icon: Icon(Icons.fact_check),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Caixa'),
                    icon: Icon(Icons.payments),
                  ),
                ],
                selected: {_isRegimeCaixa},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isRegimeCaixa = newSelection.first;
                    _gerarDre();
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((
                    states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return Theme.of(context).colorScheme.primaryContainer;
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: empresa == null
              ? const Center(child: Text('Selecione uma empresa no topo.'))
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Text(
                      _isRegimeCaixa
                          ? 'Regime de Caixa'
                          : 'Regime de Competência',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _isRegimeCaixa
                          ? 'Considera apenas os valores efetivamente pagos/recebidos.'
                          : 'Considera os fatos gerados no mês (Vendas/Contas).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _LinhaDre(
                              titulo: '(+) Receita Bruta',
                              valor: _receitaBruta,
                              cor: Colors.green,
                            ),
                            _LinhaDre(
                              titulo: '(-) Deduções/Impostos',
                              valor: _deducoes,
                              cor: Colors.red,
                            ),
                            const Divider(thickness: 1.5),
                            _LinhaDre(
                              titulo: '(=) Receita Líquida',
                              valor: receitaLiquida,
                              cor: Colors.blue,
                              isTotal: true,
                            ),
                            const SizedBox(height: 16),
                            _LinhaDre(
                              titulo: '(-) Custos Variáveis',
                              valor: _custosVariaveis,
                              cor: Colors.red,
                            ),
                            const Divider(thickness: 1.5),

                            // NOVO: Exibe o percentual na linha da Margem de Contribuição
                            _LinhaDre(
                              titulo:
                                  '(=) Margem de Contribuição (${percentualMargemContribuicao.toStringAsFixed(2)}%)',
                              valor: margemContribuicao,
                              cor: Colors.blue,
                              isTotal: true,
                            ),

                            const SizedBox(height: 16),
                            _LinhaDre(
                              titulo: '(-) Despesas Fixas',
                              valor: _despesasFixas,
                              cor: Colors.red,
                            ),
                            const Divider(thickness: 1.5),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: resultadoLiquido >= 0
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'RESULTADO DO MÊS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'R\$ ${resultadoLiquido.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: resultadoLiquido >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      color: Theme.of(context).colorScheme.primary,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Visão de Longo Prazo (Acumulado Histórico)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Resultado Meses Anteriores:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  'R\$ ${_resultadoAnteriorAcumulado.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Resultado do Mês Atual:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  'R\$ ${resultadoLiquido.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white30, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Margem de Lucro Bruta:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '${margemLucro.toStringAsFixed(2)}%',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white30, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'RESULTADO TOTAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'R\$ ${resultadoFinalHistorico.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _LinhaDre extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color cor;
  final bool isTotal;

  const _LinhaDre({
    required this.titulo,
    required this.valor,
    required this.cor,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: cor,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
