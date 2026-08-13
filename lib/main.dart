import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'services/database_helper.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Força a inicialização do banco SQLite assim que o app abrir
  await DatabaseHelper.instance.database;

  // 2. CARREGA O DICIONÁRIO PT-BR ANTES DE O APP INICIAR
  await initializeDateFormatting('pt_BR', null);

  runApp(const CoreFinanceApp());
}

class CoreFinanceApp extends StatelessWidget {
  const CoreFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoreFinance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
