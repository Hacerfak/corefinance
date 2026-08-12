import 'dart:io';

class OfxParserService {
  /// Lê o arquivo OFX e retorna uma lista de transações bancárias
  Future<List<Map<String, dynamic>>> processarOfx(File arquivoOfx) async {
    try {
      final conteudo = await arquivoOfx.readAsString();
      List<Map<String, dynamic>> transacoesBanco = [];

      // Divide o arquivo em blocos de transações (<STMTTRN> ... </STMTTRN>)
      final transacoesRaw = conteudo.split('<STMTTRN>');

      for (int i = 1; i < transacoesRaw.length; i++) {
        final bloco = transacoesRaw[i];

        // Extrai o Tipo (CREDIT ou DEBIT)
        final tipoMatch = RegExp(r'<TRNTYPE>(.*)').firstMatch(bloco);
        // Extrai a Data
        final dataMatch = RegExp(r'<DTPOSTED>(.*)').firstMatch(bloco);
        // Extrai o Valor
        final valorMatch = RegExp(r'<TRNAMT>(.*)').firstMatch(bloco);
        // Extrai a Descrição (Memo)
        final memoMatch = RegExp(r'<MEMO>(.*)').firstMatch(bloco);

        if (valorMatch != null && dataMatch != null) {
          // O formato da data OFX é YYYYMMDDHHMMSS, pegamos só a data (YYYYMMDD)
          final dataString = dataMatch.group(1)!.substring(0, 8);
          final dataFormatada =
              "${dataString.substring(0, 4)}-${dataString.substring(4, 6)}-${dataString.substring(6, 8)}";

          transacoesBanco.add({
            'tipo': tipoMatch?.group(1)?.trim() ?? 'UNKNOWN',
            'data': dataFormatada,
            'valor': double.parse(valorMatch.group(1)!.trim()),
            'descricao': memoMatch?.group(1)?.trim() ?? 'Transferência',
            'conciliado': false, // Controle de estado para a tela
          });
        }
      }

      return transacoesBanco;
    } catch (e) {
      throw Exception("Erro ao ler o arquivo OFX: $e");
    }
  }
}
