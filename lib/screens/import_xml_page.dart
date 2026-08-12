import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/xml_parser_service.dart';
import '../services/transacao_service.dart';
import '../app_state.dart';

class ImportXmlPage extends StatefulWidget {
  const ImportXmlPage({super.key});

  @override
  State<ImportXmlPage> createState() => _ImportXmlPageState();
}

class _ImportXmlPageState extends State<ImportXmlPage> {
  final XmlParserService _xmlService = XmlParserService();
  final TransacaoService _transacaoService = TransacaoService();
  Map<String, dynamic>? _dadosNota;
  bool _isLoading = false;

  Future<void> _selecionarEProcessarArquivo() async {
    final empresaAtual = AppState().empresaAtiva.value;
    if (empresaAtual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma empresa no menu!')),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      File arquivo = File(result.files.single.path!);
      try {
        final dados = await _xmlService.processarNfe(
          arquivo,
          empresaAtual.cnpj,
        );
        setState(() {
          _dadosNota = dados;
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

  Future<void> _salvarNoBanco() async {
    if (_dadosNota == null) return;
    final empresaAtual = AppState().empresaAtiva.value;
    if (empresaAtual == null) return;

    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> lote = [];
      final parcelas = _dadosNota!['parcelas'] as List;

      // Se a nota tem faturas no XML, usa elas
      if (parcelas.isNotEmpty) {
        for (int i = 0; i < parcelas.length; i++) {
          lote.add({
            'empresa_id': empresaAtual.id,
            'descricao':
                'NF ${_dadosNota!['nome_outra_parte']} (Parc ${i + 1}/${parcelas.length})',
            'tipo': _dadosNota!['tipo'],
            'documento': _dadosNota!['documento_outra_parte'],
            'valor': double.parse(parcelas[i]['valor'].toString()),
            'data_competencia': _dadosNota!['data_competencia']
                .toString()
                .substring(0, 10),
            'data_vencimento': parcelas[i]['vencimento'],
            'chave_nfe': _dadosNota!['chave_nfe'],
          });
        }
      } else {
        // Se não tem parcelas descritas, salva como parcela única à vista
        lote.add({
          'empresa_id': empresaAtual.id,
          'descricao': 'NF ${_dadosNota!['nome_outra_parte']}',
          'tipo': _dadosNota!['tipo'],
          'documento': _dadosNota!['documento_outra_parte'],
          'valor': double.parse(_dadosNota!['valor_total']),
          'data_competencia': _dadosNota!['data_competencia']
              .toString()
              .substring(0, 10),
          'data_vencimento': _dadosNota!['data_competencia']
              .toString()
              .substring(0, 10),
          'chave_nfe': _dadosNota!['chave_nfe'],
        });
      }

      await _transacaoService.criarLancamentosEmLote(lote);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NFe salva no banco!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _dadosNota = null); // Limpa a tela
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar XML'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _selecionarEProcessarArquivo,
              icon: const Icon(Icons.upload_file),
              label: const Text('Selecionar Arquivo XML da NFe'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_dadosNota != null) ...[
              const Text(
                'Resumo da Transação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  elevation: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _linhaResumo(
                          'Operação:',
                          _dadosNota!['tipo'],
                          cor: _dadosNota!['tipo'] == 'ENTRADA'
                              ? Colors.green
                              : Colors.red,
                        ),
                        _linhaResumo(
                          'Contraparte:',
                          _dadosNota!['nome_outra_parte'],
                        ),
                        _linhaResumo(
                          'Documento:',
                          _dadosNota!['documento_outra_parte'],
                        ),
                        _linhaResumo(
                          'Valor Total:',
                          'R\$ ${_dadosNota!['valor_total']}',
                        ),
                        _linhaResumo(
                          'Competência:',
                          _dadosNota!['data_competencia'].toString().substring(
                            0,
                            10,
                          ),
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Previsão de Caixa (Faturas):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...(_dadosNota!['parcelas'] as List).map(
                          (p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Vencimento: ${p['vencimento']}'),
                                Text(
                                  'R\$ ${p['valor']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if ((_dadosNota!['parcelas'] as List).isEmpty)
                          const Text(
                            "Nenhuma fatura encontrada no XML. Será salva como à vista.",
                            style: TextStyle(color: Colors.orange),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _salvarNoBanco,
                icon: const Icon(Icons.save),
                label: const Text('Confirmar e Salvar no Banco'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text('Nenhum XML processado.')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linhaResumo(String label, String valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              valor,
              style: TextStyle(fontWeight: FontWeight.bold, color: cor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
