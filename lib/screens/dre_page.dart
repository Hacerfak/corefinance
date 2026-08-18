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

  // Somatórias do novo DRE Estruturado
  double _receitaBruta = 0;
  double _deducoes = 0;
  double _csp = 0; // Custo dos Serviços Prestados
  double _despComercial = 0;
  double _despAdmin = 0;
  double _depreciacao = 0;
  double _recFinanceira = 0;
  double _despFinanceira = 0;
  double _impostos = 0;

  double _resultadoAnteriorAcumulado = 0;

  // NOVO: Mapas para guardar as categorias detalhadas de cada grupo
  final Map<String, double> _catReceitaBruta = {};
  final Map<String, double> _catDeducoes = {};
  final Map<String, double> _catCsp = {};
  final Map<String, double> _catDespComercial = {};
  final Map<String, double> _catDespAdmin = {};
  final Map<String, double> _catDepreciacao = {};
  final Map<String, double> _catRecFinanceira = {};
  final Map<String, double> _catDespFinanceira = {};
  final Map<String, double> _catImpostos = {};

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

      // Zerando os totais
      _receitaBruta = 0;
      _deducoes = 0;
      _csp = 0;
      _despComercial = 0;
      _despAdmin = 0;
      _depreciacao = 0;
      _recFinanceira = 0;
      _despFinanceira = 0;
      _impostos = 0;

      // Zerando os detalhes de categoria
      _catReceitaBruta.clear();
      _catDeducoes.clear();
      _catCsp.clear();
      _catDespComercial.clear();
      _catDespAdmin.clear();
      _catDepreciacao.clear();
      _catRecFinanceira.clear();
      _catDespFinanceira.clear();
      _catImpostos.clear();

      for (var item in dados) {
        final double valor = item['valor'];
        final String grupo = item['grupo_dre'] ?? '';
        final String catNome = item['categoria_nome'] ?? 'Sem Categoria';

        // Processa grupos novos e mantem retrocompatibilidade com os velhos, alimentando o detalhe das categorias
        if (grupo == 'RECEITA_BRUTA') {
          _receitaBruta += valor;
          _catReceitaBruta[catNome] = (_catReceitaBruta[catNome] ?? 0) + valor;
        } else if (grupo == 'DEDUCAO' || grupo == 'DEDUCAO_RECEITA') {
          _deducoes += valor;
          _catDeducoes[catNome] = (_catDeducoes[catNome] ?? 0) + valor;
        } else if (grupo == 'CUSTO_VARIAVEL' || grupo == 'CUSTO_OPERACIONAL') {
          _csp += valor;
          _catCsp[catNome] = (_catCsp[catNome] ?? 0) + valor;
        } else if (grupo == 'DESPESA_COMERCIAL') {
          _despComercial += valor;
          _catDespComercial[catNome] =
              (_catDespComercial[catNome] ?? 0) + valor;
        } else if (grupo == 'DESPESA_FIXA' ||
            grupo == 'DESPESA_ADMINISTRATIVA') {
          _despAdmin += valor;
          _catDespAdmin[catNome] = (_catDespAdmin[catNome] ?? 0) + valor;
        } else if (grupo == 'DEPRECIACAO') {
          _depreciacao += valor;
          _catDepreciacao[catNome] = (_catDepreciacao[catNome] ?? 0) + valor;
        } else if (grupo == 'RECEITA_FINANCEIRA') {
          _recFinanceira += valor;
          _catRecFinanceira[catNome] =
              (_catRecFinanceira[catNome] ?? 0) + valor;
        } else if (grupo == 'DESPESA_FINANCEIRA') {
          _despFinanceira += valor;
          _catDespFinanceira[catNome] =
              (_catDespFinanceira[catNome] ?? 0) + valor;
        } else if (grupo == 'IMPOSTO_LUCRO') {
          _impostos += valor;
          _catImpostos[catNome] = (_catImpostos[catNome] ?? 0) + valor;
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

  // NOVO: Função construtora para renderizar o Grupo com os detalhes embaixo
  Widget _renderGrupoDetalhado(
    String tituloGrupo,
    double total,
    Map<String, double> categorias,
    Color cor,
  ) {
    if (categorias.isEmpty && total == 0) {
      return _LinhaDre(
        titulo: tituloGrupo,
        valor: 0,
        cor: cor,
        isTotalGrupo: true,
      );
    }

    List<Widget> linhas = [];

    // 1. Linha do Totalizador do Grupo
    linhas.add(
      _LinhaDre(
        titulo: tituloGrupo,
        valor: total,
        cor: cor,
        isTotalGrupo: true,
      ),
    );

    // 2. Ordena as categorias do maior valor pro menor para visualização mais limpa
    final catsOrdenadas = categorias.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 3. Adiciona as linhas detalhadas
    for (var cat in catsOrdenadas) {
      linhas.add(
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: _LinhaDre(
            titulo: '↳ ${cat.key}',
            valor: cat.value,
            cor: Colors.grey[700]!,
            isCategoria: true,
          ),
        ),
      );
    }
    return Column(children: linhas);
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);
    final empresa = AppState().empresaAtiva.value;

    // Matemática Contábil e Financeira do DRE
    final receitaLiquida = _receitaBruta - _deducoes;
    final lucroBruto = receitaLiquida - _csp;
    final ebit =
        lucroBruto -
        _despComercial -
        _despAdmin -
        _depreciacao; // Resultado Operacional
    final resultadoFinanceiro = _recFinanceira - _despFinanceira;
    final lair = ebit + resultadoFinanceiro; // Lucro Antes dos Impostos
    final resultadoLiquido = lair - _impostos;

    // Percentuais Estatísticos (Base = Receita Líquida)
    final margemBrutaPct = receitaLiquida > 0
        ? (lucroBruto / receitaLiquida) * 100
        : 0.0;
    final margemEbitPct = receitaLiquida > 0
        ? (ebit / receitaLiquida) * 100
        : 0.0;
    final margemLiquidaPct = receitaLiquida > 0
        ? (resultadoLiquido / receitaLiquida) * 100
        : 0.0;

    // Histórico
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
                          ? 'Considera apenas o dinheiro que entrou e saiu no mês.'
                          : 'Considera as vendas e obrigações geradas no mês.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // CARD PRINCIPAL DO DRE ESTRUTURADO COM DETALHES
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Faturamento
                            const _TituloSecao('1. FATURAMENTO OPERACIONAL'),
                            _renderGrupoDetalhado(
                              '(+) Receita Bruta de Serviços',
                              _receitaBruta,
                              _catReceitaBruta,
                              Colors.green,
                            ),
                            _renderGrupoDetalhado(
                              '(-) Deduções e Abatimentos',
                              _deducoes,
                              _catDeducoes,
                              Colors.red,
                            ),
                            const Divider(),
                            _LinhaDre(
                              titulo: '(=) Receita Líquida de Serviços',
                              valor: receitaLiquida,
                              cor: Colors.blue,
                              isTotal: true,
                            ),

                            // 2. Margem de Serviço
                            const _TituloSecao('2. MARGEM DE SERVIÇO (COGS)'),
                            _renderGrupoDetalhado(
                              '(-) Custo dos Serv. Prestados (CSP)',
                              _csp,
                              _catCsp,
                              Colors.red,
                            ),
                            const Divider(),
                            _LinhaDre(
                              titulo:
                                  '(=) Lucro Bruto (${margemBrutaPct.toStringAsFixed(1)}%)',
                              valor: lucroBruto,
                              cor: Colors.blue,
                              isTotal: true,
                            ),

                            // 3. Estrutura Estratégica e Comercial
                            const _TituloSecao(
                              '3. ESTRUTURA ESTRATÉGICA E COMERCIAL',
                            ),
                            _renderGrupoDetalhado(
                              '(-) Despesas Comerciais e Vendas',
                              _despComercial,
                              _catDespComercial,
                              Colors.red,
                            ),
                            _renderGrupoDetalhado(
                              '(-) Despesas Admin. (Backoffice)',
                              _despAdmin,
                              _catDespAdmin,
                              Colors.red,
                            ),
                            _renderGrupoDetalhado(
                              '(-) Depreciação e Amortização',
                              _depreciacao,
                              _catDepreciacao,
                              Colors.red,
                            ),
                            const Divider(),
                            _LinhaDre(
                              titulo:
                                  '(=) Resultado Operacional (EBIT) (${margemEbitPct.toStringAsFixed(1)}%)',
                              valor: ebit,
                              cor: Colors.blue,
                              isTotal: true,
                            ),

                            // 4. Linha Financeira e Fiscal
                            const _TituloSecao('4. LINHA FINANCEIRA E FISCAL'),
                            _renderGrupoDetalhado(
                              '(+) Receitas Financeiras',
                              _recFinanceira,
                              _catRecFinanceira,
                              Colors.green,
                            ),
                            _renderGrupoDetalhado(
                              '(-) Despesas e Tarifas Financeiras',
                              _despFinanceira,
                              _catDespFinanceira,
                              Colors.red,
                            ),
                            const Divider(),
                            _LinhaDre(
                              titulo: '(=) Lucro Antes dos Impostos (LAIR)',
                              valor: lair,
                              cor: Colors.blue,
                              isTotal: true,
                            ),
                            _renderGrupoDetalhado(
                              '(-) Provisão p/ Impostos (IRPJ/CSLL)',
                              _impostos,
                              _catImpostos,
                              Colors.red,
                            ),
                            const SizedBox(height: 16),

                            // RESULTADO FINAL
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
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'LUCRO / PREJUÍZO LÍQUIDO',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Margem Líquida: ${margemLiquidaPct.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
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

                    // CARD DE HISTÓRICO E ACUMULADOS
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
                                  'RESULTADO TOTAL ACUMULADO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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

class _TituloSecao extends StatelessWidget {
  final String titulo;
  const _TituloSecao(this.titulo);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        titulo,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LinhaDre extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color cor;
  final bool isTotal;
  final bool isTotalGrupo;
  final bool isCategoria;

  const _LinhaDre({
    required this.titulo,
    required this.valor,
    required this.cor,
    this.isTotal = false,
    this.isTotalGrupo = false,
    this.isCategoria = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCategoria ? 2.0 : 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: (isTotal || isTotalGrupo)
                    ? FontWeight.bold
                    : (isCategoria ? FontWeight.normal : FontWeight.w500),
                fontSize: isTotal ? 14 : (isCategoria ? 12 : 13),
                color: isCategoria ? Colors.grey[800] : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: (isTotal || isTotalGrupo)
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: cor,
              fontSize: isTotal ? 15 : (isCategoria ? 12 : 13),
            ),
          ),
        ],
      ),
    );
  }
}
