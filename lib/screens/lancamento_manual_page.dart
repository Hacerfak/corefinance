import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/transacao_service.dart';
import '../services/categoria_service.dart';
import '../services/xml_parser_service.dart';
import '../app_state.dart';

class LancamentoManualPage extends StatefulWidget {
  final VoidCallback? onVoltarDashboard; // Callback para trocar a aba

  const LancamentoManualPage({super.key, this.onVoltarDashboard});

  @override
  State<LancamentoManualPage> createState() => _LancamentoManualPageState();
}

class _LancamentoManualPageState extends State<LancamentoManualPage> {
  final _formKey = GlobalKey<FormState>();
  final TransacaoService _transacaoService = TransacaoService();
  final CategoriaService _categoriaService = CategoriaService();
  final XmlParserService _xmlService = XmlParserService();

  List<Map<String, dynamic>> _categorias = [];
  String? _categoriaSelecionada;

  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _contraparteDocController =
      TextEditingController();
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
      if (mounted) {
        setState(() {
          _categorias = cats;
          _categoriaSelecionada = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _categorias = [];
          _categoriaSelecionada = null;
        });
      }
    }
  }

  // ==========================================
  // FUNÇÃO PARA LIMPAR TODA A TELA
  // ==========================================
  void _resetarFormulario() {
    _formKey.currentState?.reset();
    _documentoController.clear();
    _descricaoController.clear();
    _valorController.clear();
    _contraparteDocController.clear();

    setState(() {
      _tipoSelecionado = 'SAIDA';
      _categoriaSelecionada = null;
      _dataCompetencia = DateTime.now();
      _dataVencimento = DateTime.now();
      _dataPagamento = DateTime.now();
      _jaPago = false;
      _isParcelado = false;
      _qtdParcelas = 2;
      _intervaloDias = 30;
      _faturasXml.clear();
      _chaveNfe = null;
    });
  }

  // ==========================================
  // TELA DE SUCESSO (DIALOG)
  // ==========================================
  void _mostrarSucesso() {
    showDialog(
      context: context,
      barrierDismissible: false, // Impede de fechar clicando fora
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
                  Navigator.pop(context); // Fecha o dialog
                  _resetarFormulario(); // Reseta a tela
                },
                child: const Text('Novo Lançamento'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.pop(context); // Fecha o dialog
                  _resetarFormulario(); // Limpa os dados em background
                  if (widget.onVoltarDashboard != null) {
                    widget.onVoltarDashboard!(); // Troca a aba para o Dashboard
                  }
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

          _resetarFormulario(); // Limpa sujeiras anteriores antes de preencher

          setState(() {
            _tipoSelecionado = dados['tipo'];
            _documentoController.text = dados['documento'] ?? '';
            _descricaoController.text =
                dados['descricao_sugerida'] ??
                'NF ${dados['nome_outra_parte']}';
            _contraparteDocController.text =
                dados['contraparte_documento'] ?? '';
            _valorController.text = dados['valor_total'];
            _dataCompetencia = DateTime.parse(dados['data_competencia']);
            _faturasXml = List<Map<String, dynamic>>.from(dados['parcelas']);
            _chaveNfe = dados['chave_nfe'];
            _isParcelado = false;
            _jaPago = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('XML carregado! Verifique a Categoria e Salve.'),
                backgroundColor: Colors.blue,
              ),
            );
          }
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
    if (empresa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma empresa no topo!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final valorTotal = double.parse(
          _valorController.text.replaceAll(',', '.'),
        );
        final dataCompStr = _dataCompetencia.toIso8601String().split('T')[0];
        List<Map<String, dynamic>> lote = [];

        if (_faturasXml.isNotEmpty) {
          for (int i = 0; i < _faturasXml.length; i++) {
            lote.add({
              'empresa_id': empresa.id,
              'categoria_id': _tipoSelecionado == 'SALDO'
                  ? null
                  : _categoriaSelecionada,
              'documento': _documentoController.text,
              'contraparte_documento': _contraparteDocController.text.isEmpty
                  ? null
                  : _contraparteDocController.text,
              'descricao':
                  '${_descricaoController.text} (Parc ${i + 1}/${_faturasXml.length})',
              'tipo': _tipoSelecionado,
              'valor': double.parse(_faturasXml[i]['valor'].toString()),
              'data_competencia': dataCompStr,
              'data_vencimento': _faturasXml[i]['vencimento'],
              'chave_nfe': _chaveNfe,
            });
          }
        } else if (_isParcelado && _tipoSelecionado != 'SALDO') {
          final valorParcela = valorTotal / _qtdParcelas;
          for (int i = 0; i < _qtdParcelas; i++) {
            final vencimentoParcela = _dataVencimento.add(
              Duration(days: _intervaloDias * i),
            );
            lote.add({
              'empresa_id': empresa.id,
              'categoria_id': _categoriaSelecionada,
              'documento': _documentoController.text.isEmpty
                  ? null
                  : _documentoController.text,
              'contraparte_documento': _contraparteDocController.text.isEmpty
                  ? null
                  : _contraparteDocController.text,
              'descricao':
                  '${_descricaoController.text} (Parcela ${i + 1}/$_qtdParcelas)',
              'tipo': _tipoSelecionado,
              'valor': valorParcela,
              'data_competencia': dataCompStr,
              'data_vencimento': vencimentoParcela.toIso8601String().split(
                'T',
              )[0],
              'chave_nfe': _chaveNfe,
            });
          }
        } else {
          lote.add({
            'empresa_id': empresa.id,
            'categoria_id': _tipoSelecionado == 'SALDO'
                ? null
                : _categoriaSelecionada,
            'documento': _documentoController.text.isEmpty
                ? null
                : _documentoController.text,
            'contraparte_documento': _contraparteDocController.text.isEmpty
                ? null
                : _contraparteDocController.text,
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

        // MOSTRA A TELA DE SUCESSO AQUI!
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

            TextFormField(
              controller: _contraparteDocController,
              decoration: const InputDecoration(
                labelText: 'CNPJ/CPF do Cliente/Fornecedor (Opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
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
                    onTap: () => _selecionarData(
                      context,
                      _dataVencimento,
                      (d) => _dataVencimento = d,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 48),

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
            ] else if (_tipoSelecionado != 'SALDO') ...[
              SwitchListTile(
                title: const Text(
                  'Parcelar este lançamento?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _isParcelado,
                onChanged: (bool value) => setState(() {
                  _isParcelado = value;
                  if (value) _jaPago = false;
                }),
              ),
              if (_isParcelado)
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
                        onChanged: (v) => _qtdParcelas = int.tryParse(v) ?? 2,
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
                        onChanged: (v) =>
                            _intervaloDias = int.tryParse(v) ?? 30,
                      ),
                    ),
                  ],
                ),
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
            vertical: 8,
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
