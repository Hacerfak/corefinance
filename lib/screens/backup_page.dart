import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final BackupService _backupService = BackupService();
  GoogleSignInAccount? _usuarioAtual;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _verificarLogin();
  }

  Future<void> _verificarLogin() async {
    final account = await _backupService.verificarLoginSilencioso();
    setState(() => _usuarioAtual = account);
  }

  Future<void> _conectar() async {
    setState(() => _isLoading = true);
    try {
      final account = await _backupService.conectar();
      setState(() => _usuarioAtual = account);
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

  Future<void> _desconectar() async {
    await _backupService.desconectar();
    setState(() => _usuarioAtual = null);
  }

  Future<void> _executarAcao(
    Future<void> Function() acao,
    String msgSucesso,
  ) async {
    setState(() => _isLoading = true);
    try {
      await acao();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msgSucesso), backgroundColor: Colors.green),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuvem e Sincronização'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud_sync, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Mantenha seus dados seguros fazendo backup no seu próprio Google Drive.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),

            if (_usuarioAtual == null) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _conectar,
                icon: const Icon(Icons.login),
                label: const Text('Conectar com o Google'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: _usuarioAtual!.photoUrl != null
                        ? NetworkImage(_usuarioAtual!.photoUrl!)
                        : null,
                    child: _usuarioAtual!.photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(_usuarioAtual!.displayName ?? 'Usuário Google'),
                  subtitle: Text(_usuarioAtual!.email),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: _desconectar,
                    tooltip: 'Desconectar',
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _executarAcao(
                        _backupService.fazerBackup,
                        'Backup realizado com sucesso!',
                      ),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Fazer Backup Agora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _executarAcao(
                        _backupService.restaurarBackup,
                        'Dados restaurados! Reinicie o app para aplicar.',
                      ),
                icon: const Icon(Icons.cloud_download),
                label: const Text('Restaurar do Drive'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.red,
                ),
              ),
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
