import 'dart:io';
import 'package:xml/xml.dart';

class XmlParserService {
  /// Lê o arquivo XML (NF-e ou NFS-e) e retorna um mapa padronizado para a tela de lançamento
  Future<Map<String, dynamic>?> processarNfe(
    File arquivo,
    List<dynamic> empresasDisponiveis,
  ) async {
    try {
      final conteudo = await arquivo.readAsString();
      final document = XmlDocument.parse(conteudo);

      // Identifica o tipo do XML
      bool isNfse =
          document.findAllElements('NFSe').isNotEmpty ||
          document.findAllElements('infNFSe').isNotEmpty;

      String? cnpjEmitente;
      String? nomeEmitente;
      String? cnpjDestinatario;
      String? nomeDestinatario;
      String? dataEmissao;
      double valorTotal = 0.0;
      String? documentoNfe;
      String? chaveNfe;
      String descricao = '';

      if (isNfse) {
        // ==========================================
        // EXTRAÇÃO NFS-E (Nota Fiscal de Serviço)
        // ==========================================

        // Emitente (Prestador)
        final emitNode = document.findAllElements('emit').isNotEmpty
            ? document.findAllElements('emit').first
            : (document.findAllElements('prest').isNotEmpty
                  ? document.findAllElements('prest').first
                  : null);

        cnpjEmitente = emitNode?.findAllElements('CNPJ').isNotEmpty == true
            ? emitNode!.findAllElements('CNPJ').first.innerText
            : null;
        nomeEmitente = emitNode?.findAllElements('xNome').isNotEmpty == true
            ? emitNode!.findAllElements('xNome').first.innerText
            : null;

        // Destinatário (Tomador)
        final tomaNode = document.findAllElements('toma').isNotEmpty
            ? document.findAllElements('toma').first
            : null;
        cnpjDestinatario = tomaNode?.findAllElements('CNPJ').isNotEmpty == true
            ? tomaNode!.findAllElements('CNPJ').first.innerText
            : null;
        nomeDestinatario = tomaNode?.findAllElements('xNome').isNotEmpty == true
            ? tomaNode!.findAllElements('xNome').first.innerText
            : null;

        // Datas e Valores
        dataEmissao = document.findAllElements('dhEmi').isNotEmpty
            ? document.findAllElements('dhEmi').first.innerText
            : (document.findAllElements('dhProc').isNotEmpty
                  ? document.findAllElements('dhProc').first.innerText
                  : null);

        if (document.findAllElements('vLiq').isNotEmpty) {
          valorTotal =
              double.tryParse(
                document.findAllElements('vLiq').first.innerText,
              ) ??
              0.0;
        } else if (document.findAllElements('vServ').isNotEmpty) {
          valorTotal =
              double.tryParse(
                document.findAllElements('vServ').first.innerText,
              ) ??
              0.0;
        }

        // Identificadores
        documentoNfe = document.findAllElements('nNFSe').isNotEmpty
            ? document.findAllElements('nNFSe').first.innerText
            : (document.findAllElements('nDPS').isNotEmpty
                  ? document.findAllElements('nDPS').first.innerText
                  : null);

        final infNfseNode = document.findAllElements('infNFSe').isNotEmpty
            ? document.findAllElements('infNFSe').first
            : null;
        chaveNfe = infNfseNode
            ?.getAttribute('Id')
            ?.replaceAll(RegExp(r'[^0-9]'), '');

        // Descrição do Serviço
        descricao = document.findAllElements('xDescServ').isNotEmpty
            ? document.findAllElements('xDescServ').first.innerText
            : 'Serviço Prestado';
      } else {
        // ==========================================
        // EXTRAÇÃO NF-E (Nota Fiscal de Produto)
        // ==========================================

        // Emitente
        final emitNode = document.findAllElements('emit').isNotEmpty
            ? document.findAllElements('emit').first
            : null;
        cnpjEmitente = emitNode?.findAllElements('CNPJ').isNotEmpty == true
            ? emitNode!.findAllElements('CNPJ').first.innerText
            : null;
        nomeEmitente = emitNode?.findAllElements('xNome').isNotEmpty == true
            ? emitNode!.findAllElements('xNome').first.innerText
            : null;

        // Destinatário
        final destNode = document.findAllElements('dest').isNotEmpty
            ? document.findAllElements('dest').first
            : null;
        cnpjDestinatario = destNode?.findAllElements('CNPJ').isNotEmpty == true
            ? destNode!.findAllElements('CNPJ').first.innerText
            : null;
        nomeDestinatario = destNode?.findAllElements('xNome').isNotEmpty == true
            ? destNode!.findAllElements('xNome').first.innerText
            : null;

        // Datas e Valores
        dataEmissao = document.findAllElements('dhEmi').isNotEmpty
            ? document.findAllElements('dhEmi').first.innerText
            : null;
        valorTotal =
            double.tryParse(
              document.findAllElements('vNF').isNotEmpty
                  ? document.findAllElements('vNF').first.innerText
                  : '0',
            ) ??
            0.0;

        // Identificadores
        documentoNfe = document.findAllElements('nNF').isNotEmpty
            ? document.findAllElements('nNF').first.innerText
            : null;
        chaveNfe = document.findAllElements('chNFe').isNotEmpty
            ? document.findAllElements('chNFe').first.innerText
            : null;

        // Descrição baseada no primeiro produto
        descricao = document.findAllElements('xProd').isNotEmpty
            ? document.findAllElements('xProd').first.innerText
            : 'Compra/Venda de Produtos';
      }

      if (cnpjEmitente == null || cnpjDestinatario == null) return null;

      // ==========================================
      // LÓGICA DE ENTRADA OU SAÍDA (Compara com empresas locais)
      // ==========================================
      dynamic empresaIdentificada;
      String tipoTransacao = '';
      String nomeOutraParte = '';
      String cnpjOutraParte = '';

      for (var e in empresasDisponiveis) {
        String cnpjLimpo = e.cnpj.replaceAll(RegExp(r'[^0-9]'), '');
        if (cnpjEmitente == cnpjLimpo) {
          // Nós emitimos a nota -> RECEITA
          empresaIdentificada = e;
          tipoTransacao = 'ENTRADA';
          nomeOutraParte = nomeDestinatario ?? 'Desconhecido';
          cnpjOutraParte = cnpjDestinatario;
          break;
        } else if (cnpjDestinatario == cnpjLimpo) {
          // Nota emitida contra nós -> DESPESA
          empresaIdentificada = e;
          tipoTransacao = 'SAIDA';
          nomeOutraParte = nomeEmitente ?? 'Desconhecido';
          cnpjOutraParte = cnpjEmitente;
          break;
        }
      }

      if (empresaIdentificada == null) {
        throw Exception(
          'Nenhuma empresa cadastrada no app corresponde ao CNPJ do Emitente ou Destinatário/Tomador desta nota.',
        );
      }

      // ==========================================
      // EXTRAÇÃO DE FATURA / DUPLICATAS
      // ==========================================
      List<Map<String, dynamic>> parcelas = [];
      final dupNodes = document.findAllElements('dup');
      if (dupNodes.isNotEmpty) {
        for (var dup in dupNodes) {
          parcelas.add({
            'vencimento': dup.findAllElements('dVenc').isNotEmpty
                ? dup.findAllElements('dVenc').first.innerText
                : dataEmissao?.substring(0, 10),
            'valor':
                double.tryParse(
                  dup.findAllElements('vDup').isNotEmpty
                      ? dup.findAllElements('vDup').first.innerText
                      : '0',
                ) ??
                0.0,
          });
        }
      }

      // Retorno formatado para preencher a interface
      return {
        'empresa_id': empresaIdentificada.id,
        'tipo': tipoTransacao,
        'documento': documentoNfe,
        'nome_outra_parte': nomeOutraParte,
        'contraparte_documento': cnpjOutraParte,
        'descricao_sugerida': descricao, // Nova extração para ajudar a UI
        'data_competencia':
            dataEmissao?.substring(0, 10) ??
            DateTime.now().toIso8601String().substring(0, 10),
        'valor_total': valorTotal.toStringAsFixed(2),
        'parcelas': parcelas,
        'chave_nfe': chaveNfe,
      };
    } catch (e) {
      throw Exception('Falha ao processar arquivo XML: $e');
    }
  }
}
