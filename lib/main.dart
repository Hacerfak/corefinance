import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Substitua pelas suas credenciais do Supabase
  await Supabase.initialize(
    url: 'https://rblldjhbzjhhyjjvqsbr.supabase.co',
    publishableKey: 'sb_publishable_GGLUQclfy_Pp1myhwXRmMA_N_u6brUu',
  );

  runApp(const CoreFinanceApp());
}

class CoreFinanceApp extends StatelessWidget {
  const CoreFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoreFinance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
