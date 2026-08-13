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

  // Controle do Regime (Falso = Competência, Verdadeiro = Caixa)
  bool _isRegimeCaixa = false;

  // Acumuladores do DRE
  double _receitaBruta = 0;
  double _deducoes = 0;
  double _custosVariaveis = 0;
  double _despesasFixas = 0;

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
    if (empresa == null) {
      if (mounted) {
        setState(() {
          _receitaBruta = 0;
          _deducoes = 0;
          _custosVariaveis = 0;
          _despesasFixas = 0;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dados = await _transacaoService.buscarDRE(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
        regimeCaixa: _isRegimeCaixa, // Passando a escolha do usuário
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
      _gerarDre();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);
    final empresa = AppState().empresaAtiva.value;

    // --- CÁLCULOS DO DRE ---
    final receitaLiquida = _receitaBruta - _deducoes;
    final margemContribuicao = receitaLiquida - _custosVariaveis;
    final resultadoLiquido = margemContribuicao - _despesasFixas;
    final margemLucro = _receitaBruta > 0
        ? (resultadoLiquido / _receitaBruta) * 100
        : 0.0;

    // Textos dinâmicos baseados no Regime
    final tituloRegime = _isRegimeCaixa
        ? 'Regime de Caixa'
        : 'Regime de Competência';
    final descRegime = _isRegimeCaixa
        ? 'Considera apenas os valores que EFETIVAMENTE foram pagos e recebidos no mês.'
        : 'Considera os valores gerados no mês, independentemente de terem sido pagos ou não.';

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
              // SELETOR DE REGIME
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
                      tituloRegime,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      descRegime,
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
                            _LinhaDre(
                              titulo: '(=) Margem de Contribuição',
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
                                    'RESULTADO LÍQUIDO',
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

                    // Resumo Executivo Dinâmico
                    Card(
                      elevation: 1,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Análise de Performance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              resultadoLiquido >= 0
                                  ? 'A operação foi LUCRATIVA. A cada R\$ 100 ${_isRegimeCaixa ? "recebidos" : "vendidos"}, sobrou R\$ ${margemLucro.toStringAsFixed(2)} livre após deduzir os custos e despesas do período.'
                                  : 'A operação gerou PREJUÍZO. As receitas do período não foram suficientes para cobrir as saídas operacionais.',
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
          Text(
            titulo,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
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
