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
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    var users = ds.allUsers.where((u) => u.role != UserRole.client).toList();
    if (_search.isNotEmpty) {
      users = users.where((u) =>
          u.name.toLowerCase().contains(_search) ||
          u.email.toLowerCase().contains(_search)).toList();
    }
    final admins = users.where((u) => u.role == UserRole.admin).toList();
    final operators = users.where((u) => u.role == UserRole.operator).toList();

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
                              Text('Gestão de equipe e produtividade',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add, color: Colors.white),
                          onPressed: () => _showUserForm(context, null, ds),
                        ),
                      ],
                    ),
                  ),
                  // Search — só visível na aba de lista
                  AnimatedBuilder(
                    animation: _tab,
                    builder: (_, __) => _tab.index == 0
                        ? Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar por nome ou e-mail...',
                                prefixIcon:
                                    const Icon(Icons.search, size: 18),
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
                        fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Lista de Usuários'),
                      Tab(text: 'Produtividade'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Stats row (só na aba lista) ──────────────────────────────────
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
                            value: users.length,
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
                // ── Aba 1: Lista de usuários ─────────────────────────────
                users.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Nenhum usuário encontrado')
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: users.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final u = users[i];
                          return _UserCard(
                            user: u,
                            onEdit: () =>
                                _showUserForm(context, u, ds),
                            onDelete: u.id == 'user-admin'
                                ? null
                                : () =>
                                    _confirmDelete(context, u, ds),
                          );
                        },
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

  void _confirmDelete(
      BuildContext context, AppUser user, DataService ds) {
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUserForm(
      BuildContext context, AppUser? user, DataService ds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UserForm(user: user, ds: ds),
    );
  }
}

// ─── PRODUCTIVITY TAB ────────────────────────────────────────────────────

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
        // ── Resumo geral ──────────────────────────────────────────────
        _SummaryRow(stats: staffStats),
        const SizedBox(height: 16),

        // ── Cards individuais ─────────────────────────────────────────
        ...staffStats.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final color = _colors[i % _colors.length];
          final ratio =
              maxActions > 0 ? s.totalActions / maxActions : 0.0;

          return _StaffCard(
              stats: s, color: color, ratio: ratio, rank: i + 1);
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
    final totalRecv =
        stats.fold(0, (s, u) => s + u.receivingsCount);
    final totalSep =
        stats.fold(0, (s, u) => s + u.separationsCount);
    final totalShip =
        stats.fold(0, (s, u) => s + u.shippedCount);
    final totalPed =
        stats.fold(0, (s, u) => s + u.ordersCreated);

    return Row(
      children: [
        Expanded(
            child: _SummaryChip(
                '📦', '$totalRecv', 'Recebimentos',
                AppTheme.info)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryChip(
                '✂️', '$totalSep', 'Separações',
                AppTheme.warning)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryChip(
                '🚚', '$totalShip', 'Envios',
                Colors.teal)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryChip(
                '📋', '$totalPed', 'Pedidos',
                AppTheme.primary)),
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
        border:
            Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome + badge rank
          Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
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
              // Total badge
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
                        style: TextStyle(
                            color: Colors.white70, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
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

          // Detalhes de cada ação
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
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── STAT CHIP ────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── USER CARD ────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  const _UserCard(
      {required this.user, required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final roleColor =
        user.role == UserRole.admin ? AppTheme.info : AppTheme.success;
    final roleLabel =
        user.role == UserRole.admin ? 'Admin' : 'Operador';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6)
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
                    color:
                        AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Inativo',
                    style: TextStyle(
                        color: AppTheme.error, fontSize: 11)),
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

// ─── USER FORM ────────────────────────────────────────────────────────────

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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    Text(
                        isEdit
                            ? 'Editar Usuário'
                            : 'Novo Usuário',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
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
                    if (widget.ds.emailExists(v,
                        excludeId: widget.user?.id))
                      return 'E-mail já em uso';
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
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (!isEdit && (v?.isEmpty ?? true))
                      return 'Informe a senha';
                    if (v != null && v.isNotEmpty && v.length < 6)
                      return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Função:',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(width: 12),
                    _RoleChip(
                      label: 'Operador',
                      selected: _role == UserRole.operator,
                      color: AppTheme.success,
                      onTap: () =>
                          setState(() => _role = UserRole.operator),
                    ),
                    const SizedBox(width: 8),
                    _RoleChip(
                      label: 'Admin',
                      selected: _role == UserRole.admin,
                      color: AppTheme.info,
                      onTap: () =>
                          setState(() => _role = UserRole.admin),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('Usuário ativo',
                      style: TextStyle(fontSize: 13)),
                  value: _isActive,
                  activeColor: AppTheme.primary,
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(
                            isEdit
                                ? 'Salvar Alterações'
                                : 'Criar Usuário',
                            style: const TextStyle(
                                color: Colors.white)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
