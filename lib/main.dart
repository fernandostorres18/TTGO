import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'services/data_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (_) {}

  final dataService = DataService();
  dataService.initialize(); // sem await — roda em background

  runApp(
    ChangeNotifierProvider.value(
      value: dataService,
      child: const FulfillmentApp(),
    ),
  );
}

class FulfillmentApp extends StatelessWidget {
  const FulfillmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fulfillment Master',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('pt', 'BR'),
      home: const _AppGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    // Se já logado → vai para o shell principal
    if (ds.currentUser != null) return const MainShell();
    // Caso contrário → sempre mostra login (sem splash, sem loading)
    return const LoginScreen();
  }
}
