// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../models/app_models.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common_widgets.dart';
import '../core/widgets/ttgo_logo.dart';
import 'dashboard/dashboard_screen.dart';
import 'orders/orders_screen.dart';
import 'lots/lots_screen.dart';
import 'clients/clients_screen.dart';
import 'receiving/receiving_screen.dart';
import 'separation/separation_screen.dart';
import 'financial/financial_screen.dart';
import 'products/products_screen.dart';
import 'addresses/addresses_screen.dart';
import 'notifications/notifications_screen.dart';
import 'users/users_screen.dart';
import 'history/global_history_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final user = ds.currentUser!;

    if (user.role == UserRole.client) {
      return _ClientShell(user: user);
    } else if (user.role == UserRole.operator) {
      return _OperatorShell(user: user);
    } else {
      return _AdminShell(user: user);
    }
  }
}

// ─── ADMIN SHELL ──────────────────────────────────────────────────────────

class _AdminShell extends StatefulWidget {
  final AppUser user;
  const _AdminShell({required this.user});
  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _idx = 0;

  final _pages = const [
    DashboardScreen(),
    OrdersScreen(),
    LotsScreen(),
    ClientsScreen(),
    _AdminMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Lotes'),
          BottomNavigationBarItem(icon: Icon(Icons.business_outlined), activeIcon: Icon(Icons.business), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}

class _AdminMoreScreen extends StatelessWidget {
  const _AdminMoreScreen();

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final user = ds.currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: AppTheme.headerGradient,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Row(
                children: [
                  // Logo TTGO
                  const TtgoArrowIcon(size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Administrador', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MenuSection(
                    title: 'Operações',
                    items: [
                      _MenuItem(icon: Icons.move_to_inbox, title: 'Recebimento de Mercadorias', subtitle: 'Entrada via XML', color: AppTheme.info, onTap: () => _push(context, const ReceivingScreen())),
                      _MenuItem(icon: Icons.content_cut, title: 'Separação de Pedidos', subtitle: 'Bipagem e conferência', color: AppTheme.warning, onTap: () => _push(context, const SeparationScreen())),
                      _MenuItem(icon: Icons.timeline, title: 'Histórico Global', subtitle: 'Todos os eventos do sistema', color: Colors.deepOrange, onTap: () => _push(context, const GlobalHistoryScreen())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MenuSection(
                    title: 'Cadastros',
                    items: [
                      _MenuItem(icon: Icons.category_outlined, title: 'Produtos', subtitle: 'Gerenciar catálogo', color: AppTheme.primary, onTap: () => _push(context, const ProductsScreen())),
                      _MenuItem(icon: Icons.location_on_outlined, title: 'Endereços', subtitle: 'Mapa do armazém', color: Colors.teal, onTap: () => _push(context, const AddressesScreen())),
                      _MenuItem(icon: Icons.people_outline, title: 'Usuários', subtitle: 'Operadores e administradores', color: Colors.deepPurple, onTap: () => _push(context, const UsersScreen())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MenuSection(
                    title: 'Financeiro',
                    items: [
                      _MenuItem(icon: Icons.attach_money, title: 'Faturamento Mensal', subtitle: 'Relatórios e cobranças', color: Colors.green, onTap: () => _push(context, const FinancialScreen())),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, color: AppTheme.error),
                    label: const Text('Sair', style: TextStyle(color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext ctx, Widget w) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => w));
  void _logout(BuildContext ctx) {
    ctx.read<DataService>().logout();
    Navigator.pushReplacementNamed(ctx, '/login');
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Column(
            children: items.asMap().entries.map((e) => Column(
              children: [
                e.value,
                if (e.key < items.length - 1) const Divider(height: 1, indent: 56),
              ],
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint),
      onTap: onTap,
    );
  }
}

// ─── OPERATOR SHELL ───────────────────────────────────────────────────────

class _OperatorShell extends StatefulWidget {
  final AppUser user;
  const _OperatorShell({required this.user});
  @override
  State<_OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<_OperatorShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(),
      const ReceivingScreen(),
      const SeparationScreen(),
      _OperatorMoreScreen(user: widget.user),
    ];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.move_to_inbox), label: 'Recebimento'),
          BottomNavigationBarItem(icon: Icon(Icons.content_cut), label: 'Separação'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}

class _OperatorMoreScreen extends StatelessWidget {
  final AppUser user;
  const _OperatorMoreScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: AppTheme.headerGradient,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Text('Operador', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long, color: AppTheme.primary),
                    title: const Text('Pedidos em Andamento'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2, color: AppTheme.primary),
                    title: const Text('Consultar Lotes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LotsScreen())),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.error),
                    title: const Text('Sair', style: TextStyle(color: AppTheme.error)),
                    onTap: () {
                      context.read<DataService>().logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CLIENT SHELL ─────────────────────────────────────────────────────────

class _ClientShell extends StatefulWidget {
  final AppUser user;
  const _ClientShell({required this.user});
  @override
  State<_ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<_ClientShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final client = ds.getClient(widget.user.clientId ?? '');
    final pages = [
      DashboardScreen(),
      const OrdersScreen(),
      const LotsScreen(),
      _ClientMoreScreen(user: widget.user, client: client),
    ];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Meu Estoque'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}

class _ClientMoreScreen extends StatelessWidget {
  final AppUser user;
  final dynamic client;
  const _ClientMoreScreen({required this.user, this.client});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: AppTheme.headerGradient,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClientAvatar(initials: client?.initials ?? 'CL', colorIndex: 0, photoUrl: client?.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client?.companyName ?? user.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('Área do Cliente', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.analytics, color: AppTheme.primary),
                    title: const Text('Relatório Financeiro'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.category, color: AppTheme.primary),
                    title: const Text('Meus Produtos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.error),
                    title: const Text('Sair', style: TextStyle(color: AppTheme.error)),
                    onTap: () {
                      context.read<DataService>().logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
