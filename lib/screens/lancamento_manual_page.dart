import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../app_state.dart';

class LancamentoManualPage extends StatefulWidget {
  const LancamentoManualPage({super.key});

  @override
  State<LancamentoManualPage> createState() => _LancamentoManualPageState();
}

class _LancamentoManualPageState extends State<LancamentoManualPage> {
  final _formKey = GlobalKey<FormState>();
  final TransacaoService _transacaoService = TransacaoService();

  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  String _tipoSelecionado = 'SAIDA';
  DateTime _dataCompetencia = DateTime.now();
  DateTime _dataVencimento = DateTime.now();

  bool _jaPago = false;
  DateTime _dataPagamento = DateTime.now();
  bool _isLoading = false;

  // Variáveis de parcelamento
  bool _isParcelado = false;
  int _qtdParcelas = 2;
  int _intervaloDias = 30;

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
    if (escolhida != null) {
      setState(() => onSelecionado(escolhida));
    }
  }

  Future<void> _salvarLancamento() async {
    if (_formKey.currentState!.validate()) {
      final empresaAtual = AppState().empresaAtiva.value;
      if (empresaAtual == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione uma empresa primeiro!')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final valorTotal = double.parse(
          _valorController.text.replaceAll(',', '.'),
        );
        final dataCompetenciaStr = _dataCompetencia.toIso8601String().split(
          'T',
        )[0];

        List<Map<String, dynamic>> lote = [];

        if (_isParcelado) {
          final valorParcela = valorTotal / _qtdParcelas;
          for (int i = 0; i < _qtdParcelas; i++) {
            final vencimentoParcela = _dataVencimento.add(
              Duration(days: _intervaloDias * i),
            );
            lote.add({
              'empresa_id': empresaAtual.id,
              'descricao':
                  '${_descricaoController.text} (Parcela ${i + 1}/$_qtdParcelas)',
              'tipo': _tipoSelecionado,
              'valor': valorParcela,
              'data_competencia': dataCompetenciaStr,
              'data_vencimento': vencimentoParcela.toIso8601String().split(
                'T',
              )[0],
            });
          }
        } else {
          lote.add({
            'empresa_id': empresaAtual.id,
            'descricao': _descricaoController.text,
            'tipo': _tipoSelecionado,
            'valor': valorTotal,
            'data_competencia': dataCompetenciaStr,
            'data_vencimento': _dataVencimento.toIso8601String().split('T')[0],
            'data_pagamento': _jaPago
                ? _dataPagamento.toIso8601String().split('T')[0]
                : null,
          });
        }

        await _transacaoService.criarLancamentosEmLote(lote);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lançamento salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        _formKey.currentState!.reset();
        _descricaoController.clear();
        _valorController.clear();
        setState(() {
          _jaPago = false;
          _isParcelado = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Lançamento'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'ENTRADA',
                    label: Text('Receita (Entrada)'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: 'SAIDA',
                    label: Text('Despesa (Saída)'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                ],
                selected: {_tipoSelecionado},
                onSelectionChanged: (Set<String> newSelection) =>
                    setState(() => _tipoSelecionado = newSelection.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((
                    states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return _tipoSelecionado == 'ENTRADA'
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2);
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (Ex: Aluguel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Informe a descrição'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor Total (R\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Informe o valor';
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Valor inválido';
                  }
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
                      label: '1º Vencimento (Caixa)',
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
              SwitchListTile(
                title: const Text(
                  'Parcelar este lançamento?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _isParcelado,
                onChanged: (bool value) {
                  setState(() {
                    _isParcelado = value;
                    if (value) _jaPago = false;
                  });
                },
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
                  title: const Text('Lançamento já pago/recebido?'),
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
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _salvarLancamento,
                icon: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Salvando...' : 'Salvar Lançamento'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
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
