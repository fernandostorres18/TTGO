// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ttgo_logo.dart';
import '../main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final ds = context.read<DataService>();
    final ok = await ds.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    } else {
      setState(() => _error = 'E-mail ou senha incorretos');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A0DAD), // roxo TTGO escuro
              Color(0xFF7B1FA2), // roxo principal
              Color(0xFF5C0080), // roxo mais escuro base
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
              child: Column(
                children: [
                  const Spacer(),
                  // Logo TTGO — imagem com fundo transparente
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Image.asset(
                      'assets/images/ttgo_logo.png',
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const TtgoLogo(size: 90),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Sistema de Gestão Logística',
                    style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5)),
                  const Spacer(),
                  // Login Card
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Entrar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        const Text('Acesse sua conta', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outlined, color: AppTheme.primary),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: AppTheme.textHint),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                              const SizedBox(width: 8),
                              Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Entrar'),
                          ),
                        ),

                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
