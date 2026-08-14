import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class OfxParserService {
  Future<List<Map<String, dynamic>>> processarOfx(File arquivoOfx) async {
    try {
      final conteudo = await arquivoOfx.readAsString(encoding: latin1);
      List<Map<String, dynamic>> transacoesBanco = [];
      final transacoesRaw = conteudo.split('<STMTTRN>');

      for (int i = 1; i < transacoesRaw.length; i++) {
        final bloco = transacoesRaw[i];

        final tipoMatch = RegExp(r'<TRNTYPE>(.*)').firstMatch(bloco);
        final dataMatch = RegExp(r'<DTPOSTED>(.*)').firstMatch(bloco);
        final valorMatch = RegExp(r'<TRNAMT>(.*)').firstMatch(bloco);
        final memoMatch = RegExp(r'<MEMO>(.*)').firstMatch(bloco);
        final fitidMatch = RegExp(r'<FITID>(.*)').firstMatch(bloco);

        // NOVO: Captura a tag NAME
        final nomeMatch = RegExp(r'<NAME>(.*)').firstMatch(bloco);

        if (valorMatch != null && dataMatch != null) {
          String tipoBruto =
              tipoMatch
                  ?.group(1)
                  ?.replaceAll(RegExp(r'</?[^>]+>'), '')
                  .trim() ??
              '';
          String tipoMapeado = tipoBruto.toUpperCase() == 'CREDIT'
              ? 'ENTRADA'
              : 'SAIDA';

          String dataBruta = dataMatch
              .group(1)!
              .replaceAll(RegExp(r'</?[^>]+>'), '')
              .trim();
          String valorBruto = valorMatch
              .group(1)!
              .replaceAll(RegExp(r'</?[^>]+>'), '')
              .trim();
          String memoBruto =
              memoMatch
                  ?.group(1)
                  ?.replaceAll(RegExp(r'</?[^>]+>'), '')
                  .trim() ??
              'Transferência';
          String fitidBruto =
              fitidMatch
                  ?.group(1)
                  ?.replaceAll(RegExp(r'</?[^>]+>'), '')
                  .trim() ??
              const Uuid().v4();

          String? nomeBruto = nomeMatch
              ?.group(1)
              ?.replaceAll(RegExp(r'</?[^>]+>'), '')
              .trim();

          // Combina o NAME e o MEMO para criar uma descrição rica
          String descricaoFinal = memoBruto;
          String? documentoExtraido;

          if (nomeBruto != null && nomeBruto.isNotEmpty) {
            descricaoFinal = "$nomeBruto - $memoBruto";

            // Regex inteligente que captura CPFs/CNPJs mascarados ou normais (Ex: ***.130.250-** ou 64.518.671 0001-21)
            final docMatch = RegExp(
              r'([0-9*]{2,3}[\.\s]?[0-9*]{3}[\.\s]?[0-9*]{3}[ \/\-]?[0-9*]{0,4}\-?[0-9*]{2})',
            ).firstMatch(nomeBruto);
            if (docMatch != null) {
              documentoExtraido = docMatch.group(0);
            }
          }

          String dataFormatada;
          if (dataBruta.contains('-') && dataBruta.length >= 10) {
            dataFormatada = dataBruta.substring(0, 10);
          } else {
            final dataString = dataBruta.substring(0, 8);
            dataFormatada =
                "${dataString.substring(0, 4)}-${dataString.substring(4, 6)}-${dataString.substring(6, 8)}";
          }

          transacoesBanco.add({
            'fitid': fitidBruto,
            'tipo': tipoMapeado,
            'data': dataFormatada,
            'valor': double.parse(valorBruto),
            'descricao': descricaoFinal,
            'contraparte_documento': documentoExtraido, // NOVO
          });
        }
      }
      return transacoesBanco;
    } catch (e) {
      throw Exception("Erro ao ler o arquivo OFX: $e");
    }
  }
}
