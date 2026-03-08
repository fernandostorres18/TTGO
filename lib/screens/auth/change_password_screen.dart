// lib/screens/auth/change_password_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../core/theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final user = ds.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.lock_reset, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alterar Senha',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          Text('Mantenha sua conta segura',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Corpo ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Card com info do usuário
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6)
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          radius: 24,
                          child: Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _roleLabel(ds),
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Formulário
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6)
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Redefinir senha',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A nova senha deve ter no mínimo 6 caracteres.',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 18),

                          // Senha atual
                          TextFormField(
                            controller: _currentCtrl,
                            obscureText: _obscureCurrent,
                            decoration: InputDecoration(
                              labelText: 'Senha atual',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureCurrent
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscureCurrent = !_obscureCurrent),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Informe a senha atual';
                              }
                              if (v != ds.currentUser?.password) {
                                return 'Senha atual incorreta';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Nova senha
                          TextFormField(
                            controller: _newCtrl,
                            obscureText: _obscureNew,
                            decoration: InputDecoration(
                              labelText: 'Nova senha',
                              prefixIcon: const Icon(Icons.lock_open_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureNew
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscureNew = !_obscureNew),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Informe a nova senha';
                              }
                              if (v.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              if (v == _currentCtrl.text) {
                                return 'A nova senha deve ser diferente da atual';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Confirmar nova senha
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirmar nova senha',
                              prefixIcon: const Icon(Icons.verified_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Confirme a nova senha';
                              }
                              if (v != _newCtrl.text) return 'As senhas não coincidem';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Indicador de força da senha
                          _PasswordStrength(password: _newCtrl.text),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _save,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check,
                                      color: Colors.white),
                              label: Text(
                                _loading ? 'Salvando...' : 'Confirmar Alteração',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Dica de segurança
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_outlined,
                            size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dica: use letras maiúsculas, números e símbolos para uma senha mais segura.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(DataService ds) {
    if (ds.isAdmin) return 'Administrador';
    if (ds.isOperator) return 'Operador';
    return 'Cliente';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final ds = context.read<DataService>();
    await ds.changePassword(_newCtrl.text.trim());

    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Senha alterada com sucesso!'),
            ],
          ),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }
}

// ─── INDICADOR DE FORÇA DA SENHA ──────────────────────────────────────────────

class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;

    final Color color;
    final String label;
    if (score <= 1) {
      color = AppTheme.error;
      label = 'Fraca';
    } else if (score <= 3) {
      color = Colors.orange;
      label = 'Média';
    } else {
      color = AppTheme.success;
      label = 'Forte';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Força da senha:',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 5,
            minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
