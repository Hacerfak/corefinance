import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../services/categoria_service.dart';
import '../app_state.dart';

class GestaoLancamentosPage extends StatefulWidget {
  const GestaoLancamentosPage({super.key});

  @override
  State<GestaoLancamentosPage> createState() => _GestaoLancamentosPageState();
}

class _GestaoLancamentosPageState extends State<GestaoLancamentosPage> {
  final TransacaoService _transacaoService = TransacaoService();

  List<Map<String, dynamic>> _lancamentos = [];
  bool _isLoading = false;
  DateTime _mesAtual = DateTime.now();

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_carregarDados);
    _carregarDados();
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_carregarDados);
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) {
      if (mounted) setState(() => _lancamentos = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dados = await _transacaoService.buscarLancamentos(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
      );
      setState(() => _lancamentos = dados);
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
      _carregarDados();
    });
  }

  void _confirmarExclusao(String id, String descricao) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Lançamento'),
        content: Text('Tem certeza que deseja excluir "$descricao"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _transacaoService.excluirLancamento(id);
              _carregarDados();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _abrirEdicao(Map<String, dynamic> item) {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _FormularioEdicaoCompleta(
          lancamento: item,
          empresaId: empresa.id,
          onSalvo: () {
            Navigator.pop(context);
            _carregarDados();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);
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
              : _lancamentos.isEmpty
              ? const Center(child: Text('Nenhum lançamento neste mês.'))
              : ListView.builder(
                  itemCount: _lancamentos.length,
                  itemBuilder: (context, index) {
                    final item = _lancamentos[index];
                    final isEntrada = item['tipo'] == 'ENTRADA';
                    final isPago = item['data_pagamento'] != null;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPago
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          child: Icon(
                            isEntrada
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isPago ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(
                          item['descricao'],
                          style: TextStyle(
                            decoration: isPago
                                ? TextDecoration.lineThrough
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${item['categoria_nome'] ?? 'Sem Categoria'}\nVenc: ${item['data_vencimento'].toString().substring(8, 10)}/${item['data_vencimento'].toString().substring(5, 7)}' +
                              (item['documento'] != null
                                  ? ' | Doc: ${item['documento']}'
                                  : ''),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${item['valor'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isEntrada ? Colors.green : Colors.red,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'editar') {
                                  _abrirEdicao(item);
                                } else if (value == 'excluir') {
                                  _confirmarExclusao(
                                    item['id'],
                                    item['descricao'],
                                  );
                                } else if (value == 'estornar') {
                                  await _transacaoService.estornarPagamento(
                                    item['id'],
                                  );
                                  _carregarDados();
                                } else if (value == 'pagar') {
                                  await _transacaoService.registrarPagamento(
                                    item['id'],
                                    DateTime.now().toIso8601String().split(
                                      'T',
                                    )[0],
                                  );
                                  _carregarDados();
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isPago)
                                  const PopupMenuItem(
                                    value: 'pagar',
                                    child: Text('Marcar como Pago'),
                                  ),
                                if (isPago)
                                  const PopupMenuItem(
                                    value: 'estornar',
                                    child: Text('Estornar Pagamento'),
                                  ),
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Text('Editar Todos os Dados'),
                                ),
                                const PopupMenuItem(
                                  value: 'excluir',
                                  child: Text(
                                    'Excluir Lançamento',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Modal atualizado para editar TODOS os dados da conta
class _FormularioEdicaoCompleta extends StatefulWidget {
  final Map<String, dynamic> lancamento;
  final String empresaId;
  final VoidCallback onSalvo;

  const _FormularioEdicaoCompleta({
    required this.lancamento,
    required this.empresaId,
    required this.onSalvo,
  });

  @override
  State<_FormularioEdicaoCompleta> createState() =>
      _FormularioEdicaoCompletaState();
}

class _FormularioEdicaoCompletaState extends State<_FormularioEdicaoCompleta> {
  final _formKey = GlobalKey<FormState>();
  final CategoriaService _categoriaService = CategoriaService();
  final TransacaoService _transacaoService = TransacaoService();

  late TextEditingController _descCtrl;
  late TextEditingController _valorCtrl;
  late TextEditingController _docCtrl;
  late TextEditingController _chaveCtrl;

  String _tipoSelecionado = 'SAIDA';
  String? _categoriaSelecionada;
  List<Map<String, dynamic>> _categorias = [];

  DateTime _dataCompetencia = DateTime.now();
  DateTime _dataVencimento = DateTime.now();

  bool _jaPago = false;
  DateTime _dataPagamento = DateTime.now();

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.lancamento['descricao']);
    _valorCtrl = TextEditingController(
      text: widget.lancamento['valor'].toString(),
    );
    _docCtrl = TextEditingController(
      text: widget.lancamento['documento'] ?? '',
    );
    _chaveCtrl = TextEditingController(
      text: widget.lancamento['chave_nfe'] ?? '',
    );

    _tipoSelecionado = widget.lancamento['tipo'] ?? 'SAIDA';
    _categoriaSelecionada = widget.lancamento['categoria_id'];

    _dataCompetencia = DateTime.parse(widget.lancamento['data_competencia']);
    _dataVencimento = DateTime.parse(widget.lancamento['data_vencimento']);

    if (widget.lancamento['data_pagamento'] != null) {
      _jaPago = true;
      _dataPagamento = DateTime.parse(widget.lancamento['data_pagamento']);
    } else {
      _jaPago = false;
      _dataPagamento = DateTime.now();
    }

    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    final cats = await _categoriaService.buscarCategorias(widget.empresaId);
    setState(() => _categorias = cats);
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

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate()) {
      await _transacaoService.atualizarLancamento(widget.lancamento['id'], {
        'tipo': _tipoSelecionado,
        'descricao': _descCtrl.text,
        'valor': double.parse(_valorCtrl.text.replaceAll(',', '.')),
        'documento': _docCtrl.text.isEmpty ? null : _docCtrl.text,
        'chave_nfe': _chaveCtrl.text.isEmpty ? null : _chaveCtrl.text,
        'categoria_id': _categoriaSelecionada,
        'data_competencia': _dataCompetencia.toIso8601String().split('T')[0],
        'data_vencimento': _dataVencimento.toIso8601String().split('T')[0],
        'data_pagamento': _jaPago
            ? _dataPagamento.toIso8601String().split('T')[0]
            : null,
      });
      widget.onSalvo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      height:
          MediaQuery.of(context).size.height *
          0.85, // Aumentado para caber todos os dados
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Editar Lançamento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // TIPO DE TRANSAÇÃO
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
                      ],
                      selected: {_tipoSelecionado},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _tipoSelecionado = newSelection.first;
                          _categoriaSelecionada =
                              null; // Limpa a categoria ao mudar o tipo
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) {
                            if (states.contains(WidgetState.selected)) {
                              return _tipoSelecionado == 'ENTRADA'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2);
                            }
                            return Colors.transparent;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CATEGORIA
                    DropdownButtonFormField<String>(
                      value: _categoriaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
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
                      onChanged: (v) =>
                          setState(() => _categoriaSelecionada = v),
                    ),
                    const SizedBox(height: 16),

                    // DESCRIÇÃO E VALOR
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor (R\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),

                    // DOCUMENTOS
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _docCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nº Documento / NF',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _chaveCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Chave NFe (Opcional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // DATAS PRINCIPAIS
                    Row(
                      children: [
                        Expanded(
                          child: _BotaoDataEdicao(
                            label: 'Competência (DRE)',
                            data: _dataCompetencia,
                            onTap: () => _selecionarData(
                              context,
                              _dataCompetencia,
                              (d) => _dataCompetencia = d,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BotaoDataEdicao(
                            label: 'Vencimento (Caixa)',
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
                    const Divider(height: 32),

                    // PAGAMENTO
                    SwitchListTile(
                      title: const Text(
                        'Lançamento já foi pago/recebido?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _jaPago,
                      onChanged: (bool value) =>
                          setState(() => _jaPago = value),
                    ),
                    if (_jaPago)
                      _BotaoDataEdicao(
                        label: 'Data Efetiva de Pagamento',
                        data: _dataPagamento,
                        onTap: () => _selecionarData(
                          context,
                          _dataPagamento,
                          (d) => _dataPagamento = d,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _salvar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar para os botões de data no formulário de edição
class _BotaoDataEdicao extends StatelessWidget {
  final String label;
  final DateTime data;
  final VoidCallback onTap;
  const _BotaoDataEdicao({
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
