import 'dart:io';
import 'package:xml/xml.dart';
import '../app_state.dart';

class XmlParserService {
  /// Analisa o XML, descobre a empresa dona da nota e retorna os dados preenchidos
  Future<Map<String, dynamic>?> processarNfe(
    File arquivoXml,
    List<Empresa> minhasEmpresas,
  ) async {
    try {
      final xmlString = await arquivoXml.readAsString();
      final document = XmlDocument.parse(xmlString);

      // 1. Identificar CNPJs no XML
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

      String tipoTransacao = '';
      String cnpjOutraParte = '';
      String nomeOutraParte = '';
      Empresa? empresaIdentificada;

      // 2. Descobrir de qual empresa cadastrada é esta nota
      for (var emp in minhasEmpresas) {
        final meuCnpjLimpo = emp.cnpj.replaceAll(RegExp(r'[^0-9]'), '');

        if (cnpjEmitente == meuCnpjLimpo) {
          tipoTransacao = 'ENTRADA'; // Minha empresa emitiu = Venda/Receita
          cnpjOutraParte = cnpjDestinatario;
          nomeOutraParte = document
              .findAllElements('dest')
              .first
              .findElements('xNome')
              .first
              .innerText;
          empresaIdentificada = emp;
          break;
        } else if (cnpjDestinatario == meuCnpjLimpo) {
          tipoTransacao = 'SAIDA'; // Minha empresa recebeu = Compra/Despesa
          cnpjOutraParte = cnpjEmitente;
          nomeOutraParte = document
              .findAllElements('emit')
              .first
              .findElements('xNome')
              .first
              .innerText;
          empresaIdentificada = emp;
          break;
        }
      }

      if (empresaIdentificada == null) {
        throw Exception(
          "Esta nota não pertence a nenhuma das empresas cadastradas no aplicativo.",
        );
      }

      // 3. Extrair Valores e Datas
      final dataEmissao = document.findAllElements('dhEmi').first.innerText;
      final valorTotal = document.findAllElements('vNF').first.innerText;
      final documentoNfe = document.findAllElements('nNF').first.innerText;

      // 4. Faturas/Parcelas
      List<Map<String, String>> parcelas = [];
      final duplicatas = document.findAllElements('dup');
      for (var dup in duplicatas) {
        parcelas.add({
          'vencimento': dup.findElements('dVenc').first.innerText,
          'valor': dup.findElements('vDup').first.innerText,
        });
      }

      return {
        'empresa_id': empresaIdentificada.id,
        'tipo': tipoTransacao,
        'documento': documentoNfe,
        'nome_outra_parte': nomeOutraParte,
        'contraparte_documento': cnpjOutraParte, // <-- ADICIONADO
        'data_competencia': dataEmissao.substring(0, 10),
        'valor_total': valorTotal,
        'parcelas': parcelas,
        'chave_nfe': document.findAllElements('chNFe').isNotEmpty
            ? document.findAllElements('chNFe').first.innerText
            : null,
      };
    } catch (e) {
      throw Exception("Erro ao processar XML: $e");
    }
  }
}
