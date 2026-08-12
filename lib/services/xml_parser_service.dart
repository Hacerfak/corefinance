import 'dart:io';
import 'package:xml/xml.dart';

class XmlParserService {
  /// Analisa o XML e retorna um mapa com os dados financeiros da nota
  Future<Map<String, dynamic>?> processarNfe(
    File arquivoXml,
    String cnpjMinhaEmpresa,
  ) async {
    try {
      final xmlString = await arquivoXml.readAsString();
      final document = XmlDocument.parse(xmlString);

      // 1. Identificar CNPJs
      final cnpjEmitente = document
          .findAllElements('emit')
          .first
          .findElements('CNPJ')
          .first
          .innerText;
      final cnpjDestinatario = document
          .findAllElements('dest')
          .first
          .findElements('CNPJ')
          .first
          .innerText;

      // 2. Definir se é Venda (Entrada de dinheiro) ou Compra (Saída de dinheiro)
      String tipoTransacao;
      String cnpjOutraParte;
      String nomeOutraParte;

      // Remove pontuações do CNPJ da empresa logada para comparar com segurança
      final meuCnpjLimpo = cnpjMinhaEmpresa.replaceAll(RegExp(r'[^0-9]'), '');

      if (cnpjEmitente == meuCnpjLimpo) {
        tipoTransacao = 'ENTRADA'; // Minha empresa emitiu = Venda
        cnpjOutraParte = cnpjDestinatario;
        nomeOutraParte = document
            .findAllElements('dest')
            .first
            .findElements('xNome')
            .first
            .innerText;
      } else if (cnpjDestinatario == meuCnpjLimpo) {
        tipoTransacao = 'SAIDA'; // Minha empresa recebeu = Compra
        cnpjOutraParte = cnpjEmitente;
        nomeOutraParte = document
            .findAllElements('emit')
            .first
            .findElements('xNome')
            .first
            .innerText;
      } else {
        throw Exception(
          "Esta nota não pertence à empresa selecionada ($meuCnpjLimpo).",
        );
      }

      // 3. Dados para o DRE (Competência e Valor Total)
      final dataEmissao = document
          .findAllElements('dhEmi')
          .first
          .innerText; // Competência
      final valorTotal = document.findAllElements('vNF').first.innerText;

      // 4. Dados para o Fluxo de Caixa (Faturas/Duplicatas)
      List<Map<String, String>> parcelas = [];
      final duplicatas = document.findAllElements('dup');

      for (var dup in duplicatas) {
        parcelas.add({
          'vencimento': dup.findElements('dVenc').first.innerText, // Caixa
          'valor': dup.findElements('vDup').first.innerText,
        });
      }

      return {
        'tipo': tipoTransacao,
        'documento_outra_parte': cnpjOutraParte,
        'nome_outra_parte': nomeOutraParte,
        'data_competencia': dataEmissao,
        'valor_total': valorTotal,
        'parcelas': parcelas,
        'chave_nfe': document.findAllElements('chNFe').isNotEmpty
            ? document.findAllElements('chNFe').first.innerText
            : 'Sem Chave',
      };
    } catch (e) {
      print("Erro ao processar XML: $e");
      return null;
    }
  }
}
