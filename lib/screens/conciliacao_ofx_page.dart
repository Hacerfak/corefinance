import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ofx_parser_service.dart';
import '../services/conciliacao_service.dart';
import '../services/categoria_service.dart';
import '../services/parceiro_service.dart'; // <-- NOVO IMPORT
import '../app_state.dart';

class ConciliacaoOfxPage extends StatefulWidget {
  const ConciliacaoOfxPage({super.key});

  @override
  State<ConciliacaoOfxPage> createState() => _ConciliacaoOfxPageState();
}

class _ConciliacaoOfxPageState extends State<ConciliacaoOfxPage> {
  final OfxParserService _ofxService = OfxParserService();
  final ConciliacaoService _conciliacaoService = ConciliacaoService();

  List<Map<String, dynamic>> _transacoesBancarias = [];
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
      if (mounted) setState(() => _transacoesBancarias = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dados = await _conciliacaoService.buscarTransacoesBancarias(
        empresa.id,
        _mesAtual,
      );
      setState(() => _transacoesBancarias = dados);
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

  Future<void> _importarOfx() async {
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a empresa no topo primeiro!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ofx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      File arquivo = File(result.files.single.path!);
      try {
        final dadosBrutos = await _ofxService.processarOfx(arquivo);
        await _conciliacaoService.salvarTransacoesBancarias(
          empresa.id,
          dadosBrutos,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Extrato importado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _carregarDados(); // Recarrega do banco para garantir consistência
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _buscarSugestoesConciliacao(Map<String, dynamic> transacaoBanco) async {
    Navigator.pop(context);
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final sugestoes = await _conciliacaoService.buscarSugestoes(
      valorOfx: transacaoBanco['valor'],
      dataOfx: transacaoBanco['data'],
      empresaId: empresa.id,
    );

    if (!mounted) return;
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const Text(
                'Sugestões Encontradas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (sugestoes.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Nenhuma conta com valor próximo foi encontrada.',
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: sugestoes.length,
                    itemBuilder: (context, indexSugestao) {
                      final item = sugestoes[indexSugestao];
                      final double valorCandidato = double.parse(
                        item['valor'].toString(),
                      );

                      return Card(
                        color: indexSugestao == 0
                            ? Colors.green.withValues(alpha: 0.1)
                            : null,
                        child: ListTile(
                          title: Text(item['descricao']),
                          subtitle: Text(
                            'Vencimento: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(item['data_vencimento']))}',
                          ),
                          trailing: Text(
                            'R\$ ${valorCandidato.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            await _conciliacaoService.efetivarConciliacao(
                              transacaoBanco['id'],
                              item['id'].toString(),
                              transacaoBanco['data'],
                            );
                            if (mounted) Navigator.pop(context);
                            _carregarDados();
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _abrirCriarLancamento(Map<String, dynamic> transacaoBanco) async {
    Navigator.pop(context); // Fecha o menu inicial
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    // Mostra um loading rápido enquanto busca categorias e parceiros
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final categorias = await CategoriaService().buscarCategorias(empresa.id);
    final parceiros = await ParceiroService().buscarParceiros(empresa.id);

    if (!mounted) return;
    Navigator.pop(context); // Remove o loading

    String? catSelecionada;
    String? parcSelecionadoDoc;
    bool processando = false;

    // Lógica inteligente para auto-selecionar o Parceiro se o CNPJ/CPF do OFX já existir no banco
    final docOfx = transacaoBanco['contraparte_documento'];
    if (docOfx != null) {
      final cleanDocOfx = docOfx.toString().replaceAll(RegExp(r'[^0-9]'), '');
      try {
        final parceiroEncontrado = parceiros.firstWhere(
          (p) =>
              p['documento'].toString().replaceAll(RegExp(r'[^0-9]'), '') ==
              cleanDocOfx,
        );
        parcSelecionadoDoc = parceiroEncontrado['documento'];
      } catch (_) {
        // Se não encontrou, continua como null (Sem vínculo)
      }
    }

    final TextEditingController descController = TextEditingController(
      text: transacaoBanco['descricao'],
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: const Text('Novo Lançamento do OFX'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo de Descrição agora editável
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                ),
                const SizedBox(height: 16),

                // Dropdown de Parceiros com auto-seleção
                DropdownButtonFormField<String>(
                  initialValue: parcSelecionadoDoc,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cliente / Fornecedor (Opcional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sem vínculo'),
                    ),
                    ...parceiros.map(
                      (p) => DropdownMenuItem<String>(
                        value: p['documento'],
                        child: Text(
                          '${p['nome']} (${p['documento']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setStateModal(() => parcSelecionadoDoc = v),
                ),
                const SizedBox(height: 16),

                // Dados Fixos do Banco
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(DateTime.parse(transacaoBanco['data'])),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'R\$ ${transacaoBanco['valor'].abs().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Categoria (Obrigatório)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                  items: categorias
                      .where((c) => c['tipo'] == transacaoBanco['tipo'])
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['nome']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setStateModal(() => catSelecionada = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed:
                  processando ||
                      catSelecionada == null ||
                      descController.text.isEmpty
                  ? null
                  : () async {
                      setStateModal(() => processando = true);
                      await _conciliacaoService.criarLancamentoDoOfx(
                        transacaoBanco['id'],
                        {
                          'empresa_id': empresa.id,
                          'categoria_id': catSelecionada,
                          'documento': 'OFX',
                          'contraparte_documento':
                              parcSelecionadoDoc, // Salva o parceiro escolhido/detectado
                          'descricao': descController
                              .text, // Salva a descrição que o usuário editou
                          'tipo': transacaoBanco['tipo'],
                          'valor': transacaoBanco['valor'].abs(),
                          'data_competencia': transacaoBanco['data'],
                          'data_vencimento': transacaoBanco['data'],
                          'data_pagamento': transacaoBanco['data'],
                        },
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _carregarDados();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lançamento criado com sucesso!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: processando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirOpcoesConciliacao(Map<String, dynamic> transacaoBanco) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Conciliar: ${transacaoBanco['descricao']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.blue),
                title: const Text('Buscar lançamento em aberto (Sistema)'),
                onTap: () => _buscarSugestoesConciliacao(transacaoBanco),
              ),
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: const Text('Criar Novo Lançamento (Manual)'),
                onTap: () => _abrirCriarLancamento(transacaoBanco),
              ),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.orange,
                ),
                title: const Text('Apenas Ignorar / Marcar Resolvido'),
                onTap: () async {
                  Navigator.pop(context);
                  await _conciliacaoService.ignorarTransacao(
                    transacaoBanco['id'],
                  );
                  _carregarDados();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirOpcoesDesfazer(Map<String, dynamic> transacaoBanco) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desfazer Conciliação'),
        content: const Text(
          'Deseja estornar esta conciliação? A transação original voltará a ficar "Pendente".',
        ),
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
              await _conciliacaoService.desfazerConciliacao(
                transacaoBanco['id'],
              );
              _carregarDados();
            },
            child: const Text('Estornar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
    final mesCapitalizado =
        mesFormatado[0].toUpperCase() + mesFormatado.substring(1);
    final empresa = AppState().empresaAtiva.value;

    // Resumo de Progresso do Extrato
    int total = _transacoesBancarias.length;
    int concluidos = _transacoesBancarias
        .where((t) => t['conciliado'] == 1)
        .length;
    double progresso = total > 0 ? concluidos / total : 0.0;

    String periodoTexto = 'Sem dados';
    if (total > 0) {
      final datas =
          _transacoesBancarias.map((t) => DateTime.parse(t['data'])).toList()
            ..sort();
      periodoTexto =
          '${DateFormat('dd/MM/yy').format(datas.first)} até ${DateFormat('dd/MM/yy').format(datas.last)}';
    }

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

        if (empresa != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _importarOfx,
              icon: const Icon(Icons.upload_file),
              label: const Text('Importar Novo Arquivo (.ofx)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),

        if (total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Período: $periodoTexto',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '$concluidos de $total Resolvidos',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progresso,
                  backgroundColor: Colors.grey[300],
                  color: Colors.green,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

        const Divider(height: 1),

        Expanded(
          child: empresa == null
              ? const Center(child: Text('Selecione uma empresa no topo.'))
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transacoesBancarias.isEmpty
              ? const Center(child: Text('Nenhum extrato importado neste mês.'))
              : ListView.builder(
                  itemCount: _transacoesBancarias.length,
                  itemBuilder: (context, index) {
                    final transacao = _transacoesBancarias[index];
                    final bool isEntrada = transacao['tipo'] == 'ENTRADA';
                    final bool isConciliado = transacao['conciliado'] == 1;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isConciliado
                              ? Colors.green.withValues(alpha: 0.2)
                              : (isEntrada
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2)),
                          child: Icon(
                            isConciliado
                                ? Icons.check
                                : (isEntrada
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward),
                            color: isConciliado
                                ? Colors.green
                                : (isEntrada ? Colors.blue : Colors.red),
                          ),
                        ),
                        title: Text(transacao['descricao']),
                        subtitle: Text(
                          'Data: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(transacao['data']))}',
                        ),
                        trailing: Text(
                          'R\$ ${transacao['valor'].abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isConciliado
                                ? Colors.grey
                                : (isEntrada ? Colors.blue : Colors.red),
                          ),
                        ),
                        onTap: () {
                          if (isConciliado) {
                            _abrirOpcoesDesfazer(transacao);
                          } else {
                            _abrirOpcoesConciliacao(transacao);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
