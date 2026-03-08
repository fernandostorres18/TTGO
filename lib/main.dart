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

  // Inicializa Firebase com timeout — nunca bloqueia o app
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (_) {
    // Se Firebase falhar, o app ainda abre (modo offline)
  }

  final dataService = DataService();

  // initialize() NÃO bloqueia — retorna rápido e carrega em background
  dataService.initialize(); // sem await intencional

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

    // Enquanto o Firestore ainda não entregou os dados, mostra splash
    if (ds.isInitializing) {
      return const _SplashScreen();
    }

    if (ds.currentUser != null) {
      return const MainShell();
    }
    return const LoginScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A0DAD),
              Color(0xFF7B1FA2),
              Color(0xFF5C0080),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Carregando...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
