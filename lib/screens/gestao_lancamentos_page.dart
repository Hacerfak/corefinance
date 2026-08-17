import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necessário para o Clipboard (Copiar)
import 'package:intl/intl.dart';
import '../services/transacao_service.dart';
import '../services/categoria_service.dart';
import '../services/parceiro_service.dart';
import '../app_state.dart';

class GestaoLancamentosPage extends StatefulWidget {
  const GestaoLancamentosPage({super.key});

  @override
  State<GestaoLancamentosPage> createState() => _GestaoLancamentosPageState();
}

class _GestaoLancamentosPageState extends State<GestaoLancamentosPage> {
  final TransacaoService _transacaoService = TransacaoService();
  final ParceiroService _parceiroService = ParceiroService();

  List<Map<String, dynamic>> _parceiros = [];
  String? _filtroParceiro;
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
      if (mounted) {
        setState(() {
          _lancamentos = [];
          _parceiros = [];
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final parcs = await _parceiroService.buscarParceiros(empresa.id);
      final dados = await _transacaoService.buscarLancamentos(
        empresaId: empresa.id,
        mesReferencia: _mesAtual,
        parceiroDoc: _filtroParceiro, // PASSA O FILTRO
      );

      setState(() {
        _parceiros = parcs;
        _lancamentos = dados;
        // Limpa o filtro caso o parceiro não exista mais
        if (_filtroParceiro != null &&
            !_parceiros.any((p) => p['documento'] == _filtroParceiro)) {
          _filtroParceiro = null;
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

        // NOVO: DROPDOWN DE FILTRO
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
                _carregarDados(); // Recarrega os dados com o filtro ativo
              },
            ),
          ),

        Expanded(
          child: empresa == null
              ? const Center(child: Text('Selecione uma empresa no topo.'))
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _lancamentos.isEmpty
              ? const Center(child: Text('Nenhum lançamento encontrado.'))
              : ListView.builder(
                  itemCount: _lancamentos.length,
                  itemBuilder: (context, index) {
                    final item = _lancamentos[index];
                    final isEntrada = item['tipo'] == 'ENTRADA';
                    final isSaldo = item['tipo'] == 'SALDO';
                    final isPago = item['data_pagamento'] != null;

                    Color corIconeFundo = isSaldo
                        ? Colors.blue.withValues(alpha: 0.2)
                        : (isPago
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2));
                    Color corIcone = isSaldo
                        ? Colors.blue
                        : (isPago ? Colors.green : Colors.orange);
                    IconData icone = isSaldo
                        ? Icons.account_balance_wallet
                        : (isEntrada
                              ? Icons.arrow_downward
                              : Icons.arrow_upward);
                    Color corValor = isSaldo
                        ? Colors.blue
                        : (isEntrada ? Colors.green : Colors.red);

                    // Formatação do Parceiro para o Subtítulo
                    String nomeParceiro = item['parceiro_nome'] ?? '';
                    String documentoParceiro =
                        item['contraparte_documento'] ?? '';
                    String txtParceiro = '';
                    if (nomeParceiro.isNotEmpty) {
                      txtParceiro = '👤 $nomeParceiro\n';
                    } else if (documentoParceiro.isNotEmpty) {
                      txtParceiro = '👤 Doc: $documentoParceiro\n';
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 16,
                            right: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: corIconeFundo,
                            child: Icon(icone, color: corIcone),
                          ),
                          title: Text(
                            item['descricao'],
                            style: TextStyle(
                              decoration: isPago && !isSaldo
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '${isSaldo ? 'Ajuste de Caixa' : (item['categoria_nome'] ?? 'Sem Categoria')}\n'
                              '$txtParceiro'
                              'Venc: ${item['data_vencimento'].toString().substring(8, 10)}/${item['data_vencimento'].toString().substring(5, 7)}'
                              '${item['documento'] != null && item['documento'].toString().isNotEmpty ? ' | Doc: ${item['documento']}' : ''}',
                            ),
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 8.0,
                                  bottom: 4.0,
                                ),
                                child: Text(
                                  'R\$ ${item['valor'].toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: corValor,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item['chave_nfe'] != null &&
                                      item['chave_nfe'].toString().isNotEmpty)
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      icon: const Icon(
                                        Icons.copy,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                      tooltip: 'Copiar Chave NFe',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: item['chave_nfe'],
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Chave NFe copiada!'),
                                          ),
                                        );
                                      },
                                    ),
                                  if (!isSaldo)
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      icon: Icon(
                                        isPago
                                            ? Icons.undo
                                            : Icons.check_circle,
                                        color: isPago
                                            ? Colors.orange
                                            : Colors.green,
                                        size: 20,
                                      ),
                                      tooltip: isPago ? 'Estornar' : 'Pagar',
                                      onPressed: () async {
                                        if (isPago) {
                                          await _transacaoService
                                              .estornarPagamento(item['id']);
                                        } else {
                                          await _transacaoService
                                              .registrarPagamento(
                                                item['id'],
                                                DateTime.now()
                                                    .toIso8601String()
                                                    .split('T')[0],
                                              );
                                        }
                                        _carregarDados();
                                      },
                                    ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    tooltip: 'Editar',
                                    onPressed: () => _abrirEdicao(item),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    tooltip: 'Excluir',
                                    onPressed: () => _confirmarExclusao(
                                      item['id'],
                                      item['descricao'],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
  final ParceiroService _parceiroService = ParceiroService();

  late TextEditingController _descCtrl;
  late TextEditingController _valorCtrl;
  late TextEditingController _docCtrl;
  late TextEditingController _chaveCtrl;

  String _tipoSelecionado = 'SAIDA';
  String? _categoriaSelecionada;
  String? _parceiroSelecionadoDoc;

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _parceiros = [];
  bool _isCarregando = true;

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
    _parceiroSelecionadoDoc = widget.lancamento['contraparte_documento'];

    _dataCompetencia = DateTime.parse(widget.lancamento['data_competencia']);
    _dataVencimento = DateTime.parse(widget.lancamento['data_vencimento']);

    if (widget.lancamento['data_pagamento'] != null) {
      _jaPago = true;
      _dataPagamento = DateTime.parse(widget.lancamento['data_pagamento']);
    } else {
      _jaPago = false;
      _dataPagamento = DateTime.now();
    }
    _carregarCategoriasEParceiros();
  }

  Future<void> _carregarCategoriasEParceiros() async {
    final cats = await _categoriaService.buscarCategorias(widget.empresaId);
    final parcs = await _parceiroService.buscarParceiros(widget.empresaId);

    setState(() {
      _categorias = cats;
      _parceiros = parcs;

      // Segurança: se o documento salvo não existir mais, definimos como nulo
      if (_parceiroSelecionadoDoc != null &&
          !_parceiros.any((p) => p['documento'] == _parceiroSelecionadoDoc)) {
        _parceiroSelecionadoDoc = null;
      }

      // Segurança extra para a Categoria
      if (_categoriaSelecionada != null &&
          !_categorias.any((c) => c['id'] == _categoriaSelecionada)) {
        _categoriaSelecionada = null;
      }

      _isCarregando = false;
    });
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
        'documento': _docCtrl.text,
        'contraparte_documento': _parceiroSelecionadoDoc,
        'chave_nfe': _chaveCtrl.text.isEmpty ? null : _chaveCtrl.text,
        'categoria_id': _tipoSelecionado == 'SALDO'
            ? null
            : _categoriaSelecionada,
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
      height: MediaQuery.of(context).size.height * 0.85,
      child: _isCarregando
          ? const Center(child: CircularProgressIndicator())
          : Form(
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
                                label: Text('Ajuste'),
                                icon: Icon(Icons.account_balance_wallet),
                              ),
                            ],
                            selected: {_tipoSelecionado},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _tipoSelecionado = newSelection.first;
                                _categoriaSelecionada = null;
                              });
                            },
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      if (_tipoSelecionado == 'ENTRADA') {
                                        return Colors.green.withValues(
                                          alpha: 0.2,
                                        );
                                      }
                                      if (_tipoSelecionado == 'SAIDA') {
                                        return Colors.red.withValues(
                                          alpha: 0.2,
                                        );
                                      }
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
                              validator: (value) => value == null
                                  ? 'Selecione a categoria'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
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
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Valor (R\$)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _docCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Nº Documento',
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
                                    labelText: 'Chave NFe',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: _parceiroSelecionadoDoc,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Cliente / Fornecedor Vinculado',
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
                            onChanged: (v) =>
                                setState(() => _parceiroSelecionadoDoc = v),
                          ),

                          const SizedBox(height: 16),
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
                          SwitchListTile(
                            title: Text(
                              _tipoSelecionado == 'SALDO'
                                  ? 'Ajuste já realizado?'
                                  : 'Já foi pago/recebido?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: _jaPago,
                            onChanged: (bool value) =>
                                setState(() => _jaPago = value),
                          ),
                          if (_jaPago)
                            _BotaoDataEdicao(
                              label: 'Data Efetiva',
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
