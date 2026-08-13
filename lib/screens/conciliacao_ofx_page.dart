import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ofx_parser_service.dart';
import '../services/conciliacao_service.dart';
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

  @override
  void initState() {
    super.initState();
    AppState().empresaAtiva.addListener(_aoMudarEmpresa);
  }

  @override
  void dispose() {
    AppState().empresaAtiva.removeListener(_aoMudarEmpresa);
    super.dispose();
  }

  void _aoMudarEmpresa() {
    // Limpa a tela se o usuário trocar de empresa para não misturar os dados
    if (mounted) {
      setState(() {
        _transacoesBancarias.clear();
      });
    }
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
        final dados = await _ofxService.processarOfx(arquivo);
        setState(() {
          _transacoesBancarias = dados;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _buscarSugestoesConciliacao(
    Map<String, dynamic> transacaoOfx,
    int indexLista,
  ) async {
    Navigator.pop(context);
    final empresa = AppState().empresaAtiva.value;
    if (empresa == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final sugestoes = await _conciliacaoService.buscarSugestoes(
      valorOfx: transacaoOfx['valor'],
      dataOfx: transacaoOfx['data'],
      empresaId: empresa.id,
    );

    Navigator.pop(context);
    if (!mounted) return;

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
                      'Nenhuma conta com valor próximo foi encontrada nesta empresa.',
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
                            'Vencimento: ${item['data_vencimento']}',
                          ),
                          trailing: Text(
                            'R\$ ${valorCandidato.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            await _conciliacaoService.efetivarConciliacao(
                              item['id'].toString(),
                              transacaoOfx['data'],
                            );
                            Navigator.pop(context);
                            _marcarComoConciliado(indexLista);
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

  void _abrirOpcoesConciliacao(
    BuildContext context,
    Map<String, dynamic> transacao,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Conciliar: ${transacao['descricao']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.blue),
                title: const Text('Buscar lançamento em aberto (Sistema)'),
                onTap: () => _buscarSugestoesConciliacao(transacao, index),
              ),
              ListTile(
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.green,
                ),
                title: const Text('Ignorar / Marcar como Resolvido'),
                onTap: () {
                  Navigator.pop(context);
                  _marcarComoConciliado(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _marcarComoConciliado(int index) {
    setState(() => _transacoesBancarias[index]['conciliado'] = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Baixado com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _importarOfx,
            icon: const Icon(Icons.account_balance),
            label: const Text('Importar Extrato (.ofx)'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        const Divider(height: 1),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_transacoesBancarias.isEmpty)
          const Expanded(
            child: Center(child: Text('Nenhum extrato importado.')),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _transacoesBancarias.length,
              itemBuilder: (context, index) {
                final transacao = _transacoesBancarias[index];
                final bool isCredito = transacao['valor'] > 0;
                final bool isConciliado = transacao['conciliado'];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isConciliado
                          ? Colors.green.withValues(alpha: 0.2)
                          : (isCredito
                                ? Colors.blue.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2)),
                      child: Icon(
                        isConciliado
                            ? Icons.check
                            : (isCredito
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward),
                        color: isConciliado
                            ? Colors.green
                            : (isCredito ? Colors.blue : Colors.red),
                      ),
                    ),
                    title: Text(transacao['descricao']),
                    subtitle: Text('Data: ${transacao['data']}'),
                    trailing: Text(
                      'R\$ ${transacao['valor'].abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isCredito ? Colors.blue : Colors.red,
                      ),
                    ),
                    onTap: isConciliado
                        ? null
                        : () => _abrirOpcoesConciliacao(
                            context,
                            transacao,
                            index,
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
