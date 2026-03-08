// lib/screens/users/users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();

    // Equipe (admin + operadores)
    var staffUsers = ds.allUsers.where((u) => u.role != UserRole.client).toList();
    if (_search.isNotEmpty) {
      staffUsers = staffUsers
          .where((u) =>
              u.name.toLowerCase().contains(_search) ||
              u.email.toLowerCase().contains(_search))
          .toList();
    }
    final admins = staffUsers.where((u) => u.role == UserRole.admin).toList();
    final operators = staffUsers.where((u) => u.role == UserRole.operator).toList();
    final agents = staffUsers.where((u) => u.role == UserRole.supportAgent).toList();

    // Usuários clientes
    var clientUsers = ds.allUsers.where((u) => u.role == UserRole.client).toList();
    if (_search.isNotEmpty) {
      clientUsers = clientUsers
          .where((u) =>
              u.name.toLowerCase().contains(_search) ||
              u.email.toLowerCase().contains(_search))
          .toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
                    child: Row(
                      children: [
                        if (ModalRoute.of(context)?.canPop ?? false)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const SizedBox(width: 4),
                        const Icon(Icons.people, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Usuários',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              Text('Gestão de equipe e clientes',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        // Botão add contextual por aba
                        AnimatedBuilder(
                          animation: _tab,
                          builder: (_, __) {
                            if (_tab.index == 0) {
                              return IconButton(
                                icon: const Icon(Icons.person_add, color: Colors.white),
                                tooltip: 'Novo usuário da equipe',
                                onPressed: () => _showUserForm(context, null, ds),
                              );
                            } else if (_tab.index == 1) {
                              return IconButton(
                                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                                tooltip: 'Novo acesso de cliente',
                                onPressed: () => _showClientUserForm(context, null, ds),
                              );
                            }
                            return const SizedBox(width: 48);
                          },
                        ),
                      ],
                    ),
                  ),
                  // Barra de busca — abas 0 e 1
                  AnimatedBuilder(
                    animation: _tab,
                    builder: (_, __) => _tab.index < 2
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: _tab.index == 0
                                    ? 'Buscar por nome ou e-mail...'
                                    : 'Buscar cliente por nome ou e-mail...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (v) =>
                                  setState(() => _search = v.toLowerCase()),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  TabBar(
                    controller: _tab,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Equipe'),
                      Tab(text: 'Clientes'),
                      Tab(text: 'Produtividade'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Stats row (aba equipe) ──────────────────────────────────────
          AnimatedBuilder(
            animation: _tab,
            builder: (_, __) => _tab.index == 0
                ? Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _StatChip(
                            label: 'Total',
                            value: staffUsers.length,
                            color: AppTheme.primary),
                        const SizedBox(width: 8),
                        _StatChip(
                            label: 'Admins',
                            value: admins.length,
                            color: AppTheme.info),
                        const SizedBox(width: 8),
                        _StatChip(
                            label: 'Operadores',
                            value: operators.length,
                            color: AppTheme.success),
                        const SizedBox(width: 8),
                        _StatChip(
                            label: 'Atendentes',
                            value: agents.length,
                            color: Colors.teal),
                      ],
                    ),
                  )
                : _tab.index == 1
                    ? Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            _StatChip(
                                label: 'Acessos',
                                value: clientUsers.length,
                                color: Colors.indigo),
                            const SizedBox(width: 8),
                            _StatChip(
                                label: 'Ativos',
                                value: clientUsers
                                    .where((u) => u.isActive)
                                    .length,
                                color: AppTheme.success),
                            const SizedBox(width: 8),
                            _StatChip(
                                label: 'Inativos',
                                value: clientUsers
                                    .where((u) => !u.isActive)
                                    .length,
                                color: AppTheme.error),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
          ),

          // ── Tab body ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // ── Aba 0: Equipe ────────────────────────────────────────
                staffUsers.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Nenhum usuário encontrado')
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: staffUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final u = staffUsers[i];
                          return _UserCard(
                            user: u,
                            onEdit: () => _showUserForm(context, u, ds),
                            onDelete: u.id == 'user-admin'
                                ? null
                                : () => _confirmDelete(context, u, ds),
                          );
                        },
                      ),

                // ── Aba 1: Clientes ──────────────────────────────────────
                _ClientUsersTab(
                  users: clientUsers,
                  ds: ds,
                  onAdd: () => _showClientUserForm(context, null, ds),
                  onEdit: (u) => _showClientUserForm(context, u, ds),
                  onDelete: (u) => _confirmDelete(context, u, ds),
                ),

                // ── Aba 2: Produtividade ─────────────────────────────────
                _ProductivityTab(ds: ds),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppUser user, DataService ds) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Usuário'),
        content: Text(
            'Deseja excluir o usuário "${user.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ds.deleteUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Usuário "${user.name}" excluído.'),
                  backgroundColor: AppTheme.success,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child:
                const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUserForm(BuildContext context, AppUser? user, DataService ds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UserForm(user: user, ds: ds),
    );
  }

  void _showClientUserForm(BuildContext context, AppUser? user, DataService ds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClientUserForm(user: user, ds: ds),
    );
  }
}

// ─── ABA CLIENTES ────────────────────────────────────────────────────────────

class _ClientUsersTab extends StatelessWidget {
  final List<AppUser> users;
  final DataService ds;
  final VoidCallback onAdd;
  final void Function(AppUser) onEdit;
  final void Function(AppUser) onDelete;

  const _ClientUsersTab({
    required this.users,
    required this.ds,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Nenhum acesso de cliente',
        subtitle: 'Crie logins para que seus clientes\npossam acompanhar os pedidos.',
        actionLabel: 'Criar acesso',
        onAction: onAdd,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = users[i];
        final client = ds.clients.firstWhere(
          (c) => c.id == u.clientId,
          orElse: () => Client(
            id: '', companyName: 'Sem empresa', cnpjCpf: '',
            responsibleName: '', phone: '', email: '',
            contractPlan: '', minimumMonthly: 0,
            priceSmallOrder: 0, priceMediumOrder: 0,
            priceLargeOrder: 0, priceEnvelopeOrder: 0,
            createdAt: DateTime.now(),
          ),
        );
        return _ClientUserCard(
          user: u,
          clientName: client.companyName,
          onEdit: () => onEdit(u),
          onDelete: () => onDelete(u),
        );
      },
    );
  }
}

class _ClientUserCard extends StatelessWidget {
  final AppUser user;
  final String clientName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientUserCard({
    required this.user,
    required this.clientName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.indigo, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Cliente',
                  style: TextStyle(
                      color: Colors.indigo,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            if (!user.isActive) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Inativo',
                    style:
                        TextStyle(color: AppTheme.error, fontSize: 11)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            if (clientName.isNotEmpty && clientName != 'Sem empresa')
              Row(
                children: [
                  const Icon(Icons.business, size: 11,
                      color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text(clientName,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic)),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.primary),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppTheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FORMULÁRIO DE ACESSO DE CLIENTE ─────────────────────────────────────────

class _ClientUserForm extends StatefulWidget {
  final AppUser? user;
  final DataService ds;
  const _ClientUserForm({this.user, required this.ds});
  @override
  State<_ClientUserForm> createState() => _ClientUserFormState();
}

class _ClientUserFormState extends State<_ClientUserForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  String? _selectedClientId;
  late bool _isActive;
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.name ?? '');
    _email = TextEditingController(text: widget.user?.email ?? '');
    _password = TextEditingController();
    _selectedClientId = widget.user?.clientId;
    _isActive = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    final clients = widget.ds.clients;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                        isEdit
                            ? 'Editar Acesso do Cliente'
                            : 'Criar Acesso para Cliente',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'O cliente poderá acompanhar pedidos, estoque e faturamento da própria empresa.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Empresa vinculada
                DropdownButtonFormField<String>(
                  initialValue: _selectedClientId,
                  decoration: const InputDecoration(
                    labelText: 'Empresa vinculada',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: clients
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.companyName,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedClientId = v;
                      // Auto-preenche nome e email a partir do cliente
                      if (v != null && !isEdit) {
                        final c = clients.firstWhere((c) => c.id == v);
                        if (_name.text.isEmpty) {
                          _name.text = c.responsibleName;
                        }
                        if (_email.text.isEmpty) {
                          _email.text = c.email;
                        }
                      }
                    });
                  },
                  validator: (v) =>
                      v == null ? 'Selecione a empresa do cliente' : null,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Nome do responsável',
                      prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'E-mail de acesso',
                      prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Informe o e-mail';
                    if (!v!.contains('@')) return 'E-mail inválido';
                    if (widget.ds.emailExists(v, excludeId: widget.user?.id)) {
                      return 'E-mail já em uso';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: isEdit
                        ? 'Nova senha (deixe em branco para manter)'
                        : 'Senha inicial',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon:
                          Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (!isEdit && (v?.isEmpty ?? true)) {
                      return 'Informe a senha';
                    }
                    if (v != null && v.isNotEmpty && v.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  title: const Text('Acesso ativo',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                      'Cliente desativado não consegue fazer login',
                      style: TextStyle(fontSize: 11)),
                  value: _isActive,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),

                // Informativo sobre permissões
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.indigo.withValues(alpha: 0.2)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.indigo),
                        SizedBox(width: 6),
                        Text('O cliente terá acesso a:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                      ]),
                      SizedBox(height: 6),
                      _PermLine(Icons.shopping_bag_outlined,
                          'Pedidos da empresa'),
                      _PermLine(Icons.inventory_outlined,
                          'Estoque e lotes'),
                      _PermLine(Icons.attach_money_outlined,
                          'Faturamento'),
                      _PermLine(Icons.notifications_outlined,
                          'Notificações'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            isEdit ? 'Salvar Alterações' : 'Criar Acesso',
                            style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final isEdit = widget.user != null;
    final pwd = _password.text.isNotEmpty
        ? _password.text
        : (widget.user?.password ?? '');

    if (isEdit) {
      await widget.ds.updateUser(widget.user!.copyWith(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: pwd,
        clientId: _selectedClientId,
        isActive: _isActive,
      ));
    } else {
      await widget.ds.addUser(AppUser(
        id: widget.ds.newUserId(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: pwd,
        role: UserRole.client,
        clientId: _selectedClientId,
        createdAt: DateTime.now(),
        isActive: _isActive,
      ));
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit
            ? 'Acesso atualizado com sucesso!'
            : 'Acesso criado! O cliente já pode fazer login.'),
        backgroundColor: Colors.indigo,
      ));
    }
  }
}

class _PermLine extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PermLine(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.indigo.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─── PRODUCTIVITY TAB ────────────────────────────────────────────────────────

class _ProductivityTab extends StatelessWidget {
  final DataService ds;
  const _ProductivityTab({required this.ds});

  static const _colors = [
    AppTheme.primary, AppTheme.info, AppTheme.success,
    AppTheme.warning, Colors.teal, Colors.deepPurple,
  ];

  @override
  Widget build(BuildContext context) {
    final allStats = ds.getUserStats();
    final staffStats =
        allStats.where((s) => s.role != UserRole.client).toList();

    if (staffStats.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart,
        title: 'Nenhuma atividade registrada',
        subtitle: 'As ações dos funcionários aparecerão aqui.',
      );
    }

    final maxActions =
        staffStats.isNotEmpty ? staffStats.first.totalActions : 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryRow(stats: staffStats),
        const SizedBox(height: 16),
        ...staffStats.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final color = _colors[i % _colors.length];
          final ratio =
              maxActions > 0 ? s.totalActions / maxActions : 0.0;
          return _StaffCard(stats: s, color: color, ratio: ratio, rank: i + 1);
        }),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<UserStats> stats;
  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalRecv = stats.fold(0, (s, u) => s + u.receivingsCount);
    final totalSep = stats.fold(0, (s, u) => s + u.separationsCount);
    final totalShip = stats.fold(0, (s, u) => s + u.shippedCount);
    final totalPed = stats.fold(0, (s, u) => s + u.ordersCreated);

    return Row(
      children: [
        Expanded(
            child: _SummaryChip('📦', '$totalRecv', 'Recebimentos', AppTheme.info)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryChip('✂️', '$totalSep', 'Separações', AppTheme.warning)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryChip('🚚', '$totalShip', 'Envios', Colors.teal)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryChip('📋', '$totalPed', 'Pedidos', AppTheme.primary)),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;
  const _SummaryChip(this.emoji, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final UserStats stats;
  final Color color;
  final double ratio;
  final int rank;
  const _StaffCard(
      {required this.stats,
      required this.color,
      required this.ratio,
      required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text('#$rank',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stats.userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stats.role == UserRole.admin
                                ? 'Administrador'
                                : 'Operador',
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text('${stats.totalActions}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const Text('ações',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (stats.receivingsCount > 0)
                _ActionBadge(
                    icon: Icons.move_to_inbox,
                    label: '${stats.receivingsCount} recebimentos',
                    color: AppTheme.info),
              if (stats.separationsCount > 0)
                _ActionBadge(
                    icon: Icons.content_cut,
                    label: '${stats.separationsCount} separações',
                    color: AppTheme.warning),
              if (stats.shippedCount > 0)
                _ActionBadge(
                    icon: Icons.local_shipping,
                    label: '${stats.shippedCount} envios',
                    color: Colors.teal),
              if (stats.ordersCreated > 0)
                _ActionBadge(
                    icon: Icons.add_shopping_cart,
                    label: '${stats.ordersCreated} pedidos criados',
                    color: AppTheme.primary),
              if (stats.finalizedCount > 0)
                _ActionBadge(
                    icon: Icons.done_all,
                    label: '${stats.finalizedCount} finalizados',
                    color: AppTheme.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ActionBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── STAT CHIP ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── USER CARD ────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  const _UserCard(
      {required this.user, required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final roleColor = user.role == UserRole.admin
        ? AppTheme.info
        : user.role == UserRole.supportAgent
            ? Colors.teal
            : AppTheme.success;
    final roleLabel = user.role == UserRole.admin
        ? 'Admin'
        : user.role == UserRole.supportAgent
            ? 'Atendente'
            : 'Operador';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
                color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14))),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(roleLabel,
                  style: TextStyle(
                      color: roleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            if (!user.isActive) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Inativo',
                    style:
                        TextStyle(color: AppTheme.error, fontSize: 11)),
              ),
            ],
          ],
        ),
        subtitle: Text(user.email,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.primary),
              onPressed: onEdit,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.error),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── USER FORM ────────────────────────────────────────────────────────────────

class _UserForm extends StatefulWidget {
  final AppUser? user;
  final DataService ds;
  const _UserForm({this.user, required this.ds});
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late UserRole _role;
  late bool _isActive;
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.name ?? '');
    _email = TextEditingController(text: widget.user?.email ?? '');
    _password = TextEditingController();
    _role = widget.user?.role ?? UserRole.operator;
    _isActive = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(isEdit ? 'Editar Usuário' : 'Novo Usuário',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Informe o e-mail';
                    if (!v!.contains('@')) return 'E-mail inválido';
                    if (widget.ds.emailExists(v, excludeId: widget.user?.id)) {
                      return 'E-mail já em uso';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: isEdit
                        ? 'Nova senha (deixe em branco para manter)'
                        : 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (!isEdit && (v?.isEmpty ?? true)) {
                      return 'Informe a senha';
                    }
                    if (v != null && v.isNotEmpty && v.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Função:',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(width: 12),
                    _RoleChip(
                      label: 'Operador',
                      selected: _role == UserRole.operator,
                      color: AppTheme.success,
                      onTap: () => setState(() => _role = UserRole.operator),
                    ),
                    const SizedBox(width: 8),
                    _RoleChip(
                      label: 'Atendente',
                      selected: _role == UserRole.supportAgent,
                      color: Colors.teal,
                      onTap: () => setState(() => _role = UserRole.supportAgent),
                    ),
                    const SizedBox(width: 8),
                    _RoleChip(
                      label: 'Admin',
                      selected: _role == UserRole.admin,
                      color: AppTheme.info,
                      onTap: () => setState(() => _role = UserRole.admin),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('Usuário ativo',
                      style: TextStyle(fontSize: 13)),
                  value: _isActive,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            isEdit ? 'Salvar Alterações' : 'Criar Usuário',
                            style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final isEdit = widget.user != null;
    final pwd = _password.text.isNotEmpty
        ? _password.text
        : (widget.user?.password ?? '');
    if (isEdit) {
      await widget.ds.updateUser(widget.user!.copyWith(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: pwd,
        role: _role,
        isActive: _isActive,
      ));
    } else {
      await widget.ds.addUser(AppUser(
        id: widget.ds.newUserId(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: pwd,
        role: _role,
        createdAt: DateTime.now(),
        isActive: _isActive,
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _RoleChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            )),
      ),
    );
  }
}
