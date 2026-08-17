import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/transacao_service.dart';
import '../services/categoria_service.dart';
import '../services/parceiro_service.dart';
import '../services/xml_parser_service.dart';
import '../app_state.dart';

class LancamentoManualPage extends StatefulWidget {
  final VoidCallback? onVoltarDashboard;
  const LancamentoManualPage({super.key, this.onVoltarDashboard});

  @override
  State<LancamentoManualPage> createState() => _LancamentoManualPageState();
}

class _LancamentoManualPageState extends State<LancamentoManualPage> {
  final _formKey = GlobalKey<FormState>();
  final TransacaoService _transacaoService = TransacaoService();
  final CategoriaService _categoriaService = CategoriaService();
  final ParceiroService _parceiroService = ParceiroService();
  final XmlParserService _xmlService = XmlParserService();

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _parceiros = [];
  String? _categoriaSelecionada;
  String? _parceiroSelecionadoDoc;

  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  String _tipoSelecionado = 'SAIDA';
  DateTime _dataCompetencia = DateTime.now();
  DateTime _dataVencimento = DateTime.now();
  bool _jaPago = false;
  DateTime _dataPagamento = DateTime.now();
  bool _isLoading = false;

  bool _isParcelado = false;
  int _qtdParcelas = 2;
  int _intervaloDias = 30;

  List<Map<String, dynamic>> _faturasXml = [];
  List<Map<String, dynamic>> _parcelasManuais =
      []; // Guarda as parcelas projetadas na tela
  String? _chaveNfe;

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_aoMudarEmpresa);
    _aoMudarEmpresa();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_aoMudarEmpresa);
    super.dispose();
  }

  void _aoMudarEmpresa() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa != null) {
      final cats = await _categoriaService.buscarCategorias(empresa.id);
      final parcs = await _parceiroService.buscarParceiros(empresa.id);
      if (mounted) {
        setState(() {
          _categorias = cats;
          _parceiros = parcs;
          _categoriaSelecionada = null;
          _parceiroSelecionadoDoc = null;
        });
      }
    } else {
      if (mounted)
        setState(() {
          _categorias = [];
          _parceiros = [];
          _categoriaSelecionada = null;
          _parceiroSelecionadoDoc = null;
        });
    }
  }

  void _resetarFormulario() {
    _formKey.currentState?.reset();
    _documentoController.clear();
    _descricaoController.clear();
    _valorController.clear();

    setState(() {
      _tipoSelecionado = 'SAIDA';
      _categoriaSelecionada = null;
      _parceiroSelecionadoDoc = null;
      _dataCompetencia = DateTime.now();
      _dataVencimento = DateTime.now();
      _dataPagamento = DateTime.now();
      _jaPago = false;
      _isParcelado = false;
      _qtdParcelas = 2;
      _intervaloDias = 30;
      _faturasXml.clear();
      _parcelasManuais.clear();
      _chaveNfe = null;
    });
  }

  // ==========================================
  // LÓGICA INTELIGENTE DE PARCELAMENTO
  // ==========================================
  void _gerarParcelas() {
    if (_valorController.text.isEmpty) return;
    double valorTotal =
        double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;

    if (valorTotal == 0 || _qtdParcelas <= 0) {
      setState(() => _parcelasManuais.clear());
      return;
    }

    double valorBase = valorTotal / _qtdParcelas;
    // Arredonda para 2 casas para evitar dízimas (ex: 100 / 3 = 33.33)
    double valorArredondado = double.parse(valorBase.toStringAsFixed(2));

    // Calcula a diferença de centavos para jogar na última parcela (ex: a última fica com 33.34)
    double soma = valorArredondado * (_qtdParcelas - 1);
    double valorUltima = valorTotal - soma;

    _parcelasManuais.clear();
    for (int i = 0; i < _qtdParcelas; i++) {
      DateTime venc = _dataVencimento.add(Duration(days: _intervaloDias * i));
      _parcelasManuais.add({
        'vencimento': venc.toIso8601String().split('T')[0],
        'valor': i == _qtdParcelas - 1 ? valorUltima : valorArredondado,
      });
    }
    setState(() {});
  }

  void _mostrarSucesso() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Sucesso!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'O lançamento foi salvo com sucesso.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _resetarFormulario();
                },
                child: const Text('Novo Lançamento'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _resetarFormulario();
                  if (widget.onVoltarDashboard != null)
                    widget.onVoltarDashboard!();
                },
                child: const Text('Ir para o Dashboard'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importarEPreencherViaXml() async {
    final empresasCadastradas = AppState().empresasDisponiveis.value;
    if (empresasCadastradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre uma empresa primeiro.')),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        File arquivo = File(result.files.single.path!);
        final dados = await _xmlService.processarNfe(
          arquivo,
          empresasCadastradas,
        );

        if (dados != null) {
          final empresaEncontrada = empresasCadastradas.firstWhere(
            (e) => e.id == dados['empresa_id'],
          );
          AppState().empresaAtiva.value = empresaEncontrada;

          _resetarFormulario();

          if (dados['contraparte_documento'] != null &&
              dados['nome_outra_parte'] != null) {
            await _parceiroService.salvarParceiroDoXml(
              empresaId: empresaEncontrada.id,
              documento: dados['contraparte_documento'],
              nome: dados['nome_outra_parte'],
            );
          }
          final parcs = await _parceiroService.buscarParceiros(
            empresaEncontrada.id,
          );

          setState(() {
            _parceiros = parcs;
            _tipoSelecionado = dados['tipo'];
            _documentoController.text = dados['documento'] ?? '';
            _descricaoController.text =
                dados['descricao_sugerida'] ??
                'NF ${dados['nome_outra_parte']}';
            _parceiroSelecionadoDoc = dados['contraparte_documento'];
            _valorController.text = dados['valor_total'];
            _dataCompetencia = DateTime.parse(dados['data_competencia']);
            _faturasXml = List<Map<String, dynamic>>.from(dados['parcelas']);
            _chaveNfe = dados['chave_nfe'];
            _isParcelado = false;
            _jaPago = false;
          });

          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('XML carregado! Verifique a Categoria e Salve.'),
                backgroundColor: Colors.blue,
              ),
            );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selecionarData(
    BuildContext context,
    DateTime dataAtual,
    Function(DateTime) onSelecionado,
  ) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: dataAtual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (escolhida != null) setState(() => onSelecionado(escolhida));
  }

  Future<void> _salvarLancamento() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final valorTotal = double.parse(
          _valorController.text.replaceAll(',', '.'),
        );
        final dataCompStr = _dataCompetencia.toIso8601String().split('T')[0];
        List<Map<String, dynamic>> lote = [];

        // 1. Fluxo XML Faturas
        if (_faturasXml.isNotEmpty) {
          for (int i = 0; i < _faturasXml.length; i++) {
            lote.add({
              'empresa_id': empresa.id,
              'categoria_id': _tipoSelecionado == 'SALDO'
                  ? null
                  : _categoriaSelecionada,
              'documento': _documentoController.text,
              'contraparte_documento': _parceiroSelecionadoDoc,
              'descricao':
                  '${_descricaoController.text} (Parc ${i + 1}/${_faturasXml.length})',
              'tipo': _tipoSelecionado,
              'valor': double.parse(_faturasXml[i]['valor'].toString()),
              'data_competencia': dataCompStr,
              'data_vencimento': _faturasXml[i]['vencimento'],
              'chave_nfe': _chaveNfe,
            });
          }
          // 2. Fluxo de Parcelas Manuais
        } else if (_isParcelado && _tipoSelecionado != 'SALDO') {
          if (_parcelasManuais.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'As parcelas não foram geradas. Desative e ative o parcelamento.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isLoading = false);
            return;
          }

          for (int i = 0; i < _parcelasManuais.length; i++) {
            lote.add({
              'empresa_id': empresa.id,
              'categoria_id': _categoriaSelecionada,
              'documento': _documentoController.text.isEmpty
                  ? null
                  : _documentoController.text,
              'contraparte_documento': _parceiroSelecionadoDoc,
              'descricao':
                  '${_descricaoController.text} (Parcela ${i + 1}/${_parcelasManuais.length})',
              'tipo': _tipoSelecionado,
              'valor':
                  _parcelasManuais[i]['valor'], // Pega o valor exato ajustado na tela
              'data_competencia': dataCompStr,
              'data_vencimento':
                  _parcelasManuais[i]['vencimento'], // Pega a data exata ajustada na tela
              'chave_nfe': _chaveNfe,
            });
          }
          // 3. Fluxo Padrão (Cota Única ou Saldo)
        } else {
          lote.add({
            'empresa_id': empresa.id,
            'categoria_id': _tipoSelecionado == 'SALDO'
                ? null
                : _categoriaSelecionada,
            'documento': _documentoController.text.isEmpty
                ? null
                : _documentoController.text,
            'contraparte_documento': _parceiroSelecionadoDoc,
            'descricao': _descricaoController.text,
            'tipo': _tipoSelecionado,
            'valor': valorTotal,
            'data_competencia': dataCompStr,
            'data_vencimento': _dataVencimento.toIso8601String().split('T')[0],
            'data_pagamento': _jaPago || _tipoSelecionado == 'SALDO'
                ? _dataPagamento.toIso8601String().split('T')[0]
                : null,
            'chave_nfe': _chaveNfe,
          });
        }

        await _transacaoService.criarLancamentosEmLote(lote);
        if (!mounted) return;
        _mostrarSucesso();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppState().empresaAtiva.value == null) {
      return const Center(
        child: Text('Selecione a empresa dona do lançamento no topo.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _importarEPreencherViaXml,
              icon: const Icon(Icons.auto_fix_high, color: Colors.purple),
              label: const Text('Preencher Formulário via XML (NFe/NFSe)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.purple),
              ),
            ),
            const SizedBox(height: 24),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'ENTRADA',
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: 'SAIDA',
                  label: Text('Despesa'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: 'SALDO',
                  label: Text('Saldo Inicial'),
                  icon: Icon(Icons.account_balance_wallet),
                ),
              ],
              selected: {_tipoSelecionado},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _tipoSelecionado = newSelection.first;
                  _categoriaSelecionada = null;
                  if (_tipoSelecionado == 'SALDO') {
                    _isParcelado = false;
                    _parcelasManuais.clear();
                    _jaPago = true;
                  }
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    if (_tipoSelecionado == 'ENTRADA')
                      return Colors.green.withValues(alpha: 0.2);
                    if (_tipoSelecionado == 'SAIDA')
                      return Colors.red.withValues(alpha: 0.2);
                    return Colors.blue.withValues(alpha: 0.2);
                  }
                  return Colors.transparent;
                }),
              ),
            ),
            const SizedBox(height: 16),

            if (_tipoSelecionado != 'SALDO') ...[
              DropdownButtonFormField<String>(
                value: _categoriaSelecionada,
                decoration: const InputDecoration(
                  labelText: 'Categoria (Plano de Contas)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categorias
                    .where((c) => c['tipo'] == _tipoSelecionado)
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['nome']),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _categoriaSelecionada = v),
                validator: (value) =>
                    value == null ? 'Selecione a categoria' : null,
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _documentoController,
                    decoration: const InputDecoration(
                      labelText: 'Nº Documento / NF',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _descricaoController,
                    decoration: InputDecoration(
                      labelText: _tipoSelecionado == 'SALDO'
                          ? 'Descrição (Ex: Saldo Banco X)'
                          : 'Descrição (Ex: Aluguel)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe a descrição' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _parceiroSelecionadoDoc,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cliente / Fornecedor Vinculado (Opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Sem vínculo'),
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
              onChanged: (v) => setState(() => _parceiroSelecionadoDoc = v),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: _tipoSelecionado == 'SALDO'
                    ? 'Valor (Use - para ajustes negativos)'
                    : 'Valor Total (R\$)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              // REMOVIDO: onChanged que forçava o _gerarParcelas()
              validator: (value) {
                if (value == null || value.isEmpty) return 'Informe o valor';
                if (double.tryParse(value.replaceAll(',', '.')) == null)
                  return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _BotaoData(
                    label: 'Competência (DRE)',
                    data: _dataCompetencia,
                    onTap: () => _selecionarData(
                      context,
                      _dataCompetencia,
                      (d) => _dataCompetencia = d,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BotaoData(
                    label: _tipoSelecionado == 'SALDO'
                        ? 'Data do Ajuste'
                        : 'Vencimento Base',
                    data: _dataVencimento,
                    onTap: () => _selecionarData(context, _dataVencimento, (d) {
                      _dataVencimento = d;
                      // REMOVIDO: recálculo automático no vencimento base
                    }),
                  ),
                ),
              ],
            ),
            const Divider(height: 48),

            // MODO DE IMPORTAÇÃO XML
            if (_faturasXml.isNotEmpty && _tipoSelecionado != 'SALDO') ...[
              const Text(
                'Faturas importadas da NFe/NFSe:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.purple.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: _faturasXml
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Vencimento: ${f['vencimento']}'),
                                Text(
                                  'R\$ ${f['valor']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

              // MODO DE PARCELAMENTO MANUAL
            ] else if (_tipoSelecionado != 'SALDO') ...[
              SwitchListTile(
                title: const Text(
                  'Parcelar este lançamento?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _isParcelado,
                onChanged: (bool value) => setState(() {
                  _isParcelado = value;
                  if (value) {
                    _jaPago = false;
                    _gerarParcelas(); // Só recalcula quando LIGA a chave
                  } else {
                    _parcelasManuais.clear();
                  }
                }),
              ),

              if (_isParcelado) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_qtdParcelas',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Qtd de Parcelas',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _qtdParcelas = int.tryParse(v) ?? 2;
                          _gerarParcelas();
                        }, // Recalcula se mudar a Quantidade
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_intervaloDias',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Intervalo (Dias)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _intervaloDias = int.tryParse(v) ?? 30;
                          _gerarParcelas();
                        }, // Recalcula se mudar o Intervalo
                      ),
                    ),
                  ],
                ),

                if (_parcelasManuais.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Ajuste Fino das Parcelas:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: _parcelasManuais.asMap().entries.map((entry) {
                          int i = entry.key;
                          Map<String, dynamic> p = entry.value;
                          DateTime dataParc = DateTime.parse(p['vencimento']);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                Text(
                                  '${i + 1}ª',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _BotaoData(
                                    label: 'Vencimento',
                                    data: dataParc,
                                    onTap: () => _selecionarData(
                                      context,
                                      dataParc,
                                      (d) {
                                        setState(
                                          () =>
                                              _parcelasManuais[i]['vencimento'] =
                                                  d.toIso8601String().split(
                                                    'T',
                                                  )[0],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: p['valor'].toStringAsFixed(2),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Valor (R\$)',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (v) =>
                                        _parcelasManuais[i]['valor'] =
                                            double.tryParse(
                                              v.replaceAll(',', '.'),
                                            ) ??
                                            0.0,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],

              if (!_isParcelado) ...[
                SwitchListTile(
                  title: const Text('Lançamento já foi pago/recebido?'),
                  value: _jaPago,
                  onChanged: (bool value) => setState(() => _jaPago = value),
                ),
                if (_jaPago)
                  _BotaoData(
                    label: 'Data Efetiva',
                    data: _dataPagamento,
                    onTap: () => _selecionarData(
                      context,
                      _dataPagamento,
                      (d) => _dataPagamento = d,
                    ),
                  ),
              ],
            ],

            if (_tipoSelecionado == 'SALDO') ...[
              SwitchListTile(
                title: const Text('Ajuste já foi realizado no banco?'),
                value: _jaPago,
                onChanged: (bool value) => setState(() => _jaPago = value),
              ),
              if (_jaPago)
                _BotaoData(
                  label: 'Data Efetiva do Ajuste',
                  data: _dataPagamento,
                  onTap: () => _selecionarData(
                    context,
                    _dataPagamento,
                    (d) => _dataPagamento = d,
                  ),
                ),
            ],

            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _salvarLancamento,
              icon: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Processando...' : 'Salvar Lançamento'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoData extends StatelessWidget {
  final String label;
  final DateTime data;
  final VoidCallback onTap;
  const _BotaoData({
    required this.label,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd/MM/yyyy').format(data)),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }
}
