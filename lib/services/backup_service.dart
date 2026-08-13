import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class BackupService {
  static final BackupService _instancia = BackupService._interno();
  factory BackupService() => _instancia;
  BackupService._interno();

  // Escopo necessário para salvar na pasta oculta do app no Drive
  final List<String> _scopes = [drive.DriveApi.driveAppdataScope];

  GoogleSignInAccount? _usuarioAtual;
  GoogleSignInAccount? get currentUser => _usuarioAtual;

  /// Inicializa a instância do Google Sign-In v7
  Future<void> inicializar() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize();
  }

  /// Tenta o login leve/silencioso sem abrir janelas nativas
  Future<GoogleSignInAccount?> verificarLoginSilencioso() async {
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      await signIn.attemptLightweightAuthentication();
      return _usuarioAtual;
    } catch (e) {
      return null;
    }
  }

  /// Realiza o login interativo chamando o modal do Google
  Future<GoogleSignInAccount?> conectar() async {
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();

      if (signIn.supportsAuthenticate()) {
        final account = await signIn.authenticate();
        // Solicita autorização para o escopo do Google Drive
        await account.authorizationClient.authorizeScopes(_scopes);
        _usuarioAtual = account;
        return account;
      } else {
        throw Exception('A plataforma atual não suporta autenticação direta.');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o Google: $e');
    }
  }

  /// Desconecta o usuário
  Future<void> desconectar() async {
    await GoogleSignIn.instance.disconnect();
    _usuarioAtual = null;
  }

  /// Obtém o cliente autenticado da API do Drive gerenciando as permissões de escopo
  Future<drive.DriveApi?> _obterDriveApi() async {
    var user = _usuarioAtual;
    user ??= await conectar();
    if (user == null) return null;

    // Obtém o token de autorização específico para o escopo do Drive
    var auth = await user.authorizationClient.authorizationForScopes(_scopes);

    if (auth == null) {
      auth = await user.authorizationClient.authorizeScopes(_scopes);
    }

    final accessToken = auth.accessToken;

    final headers = {'Authorization': 'Bearer $accessToken'};
    final authenticateClient = GoogleAuthClient(headers);
    return drive.DriveApi(authenticateClient);
  }

  /// Faz o upload do banco SQLite para o Google Drive
  Future<void> fazerBackup() async {
    final driveApi = await _obterDriveApi();
    if (driveApi == null) throw Exception('Usuário não autenticado.');

    final dbPath = await getDatabasesPath();
    final file = File(p.join(dbPath, 'corefinance.db'));

    if (!await file.exists()) {
      throw Exception('Banco de dados local não encontrado.');
    }

    // Consulta se já existe um arquivo salvo na pasta de dados do App
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = 'corefinance_backup.db'",
    );

    final driveFile = drive.File()..name = 'corefinance_backup.db';
    driveFile.parents = ['appDataFolder'];

    final media = drive.Media(file.openRead(), file.lengthSync());

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final fileId = fileList.files!.first.id!;
      await driveApi.files.update(driveFile, fileId, uploadMedia: media);
    } else {
      await driveApi.files.create(driveFile, uploadMedia: media);
    }
  }

  /// Restaura o arquivo `.db` do Google Drive para o dispositivo local
  Future<void> restaurarBackup() async {
    final driveApi = await _obterDriveApi();
    if (driveApi == null) throw Exception('Usuário não autenticado.');

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = 'corefinance_backup.db'",
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception('Nenhum backup encontrado na sua conta do Google Drive.');
    }

    final fileId = fileList.files!.first.id!;
    final response =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final dbPath = await getDatabasesPath();
    final file = File(p.join(dbPath, 'corefinance.db'));

    final sink = file.openWrite();
    await response.stream.pipe(sink);
    await sink.flush();
    await sink.close();
  }
}
