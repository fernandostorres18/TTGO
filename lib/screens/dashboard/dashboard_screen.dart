// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../orders/orders_screen.dart';
import '../lots/lots_screen.dart';
import '../notifications/notifications_screen.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

bool _isWide(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700;

/// Centraliza e limita a largura em desktop/web; na mobile ocupa tudo.
Widget _constrained(BuildContext context, Widget child) {
  if (!_isWide(context)) return child;
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: child,
    ),
  );
}

// ─── ROUTER ────────────────────────────────────────────────────────────────

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final user = ds.currentUser!;

    if (user.role == UserRole.admin || user.role == UserRole.operator) {
      return _AdminDashboard(ds: ds, user: user);
    } else {
      return _ClientDashboard(ds: ds, user: user);
    }
  }
}

// ─── ADMIN DASHBOARD ──────────────────────────────────────────────────────

class _AdminDashboard extends StatelessWidget {
  final DataService ds;
  final AppUser user;
  const _AdminDashboard({required this.ds, required this.user});

  @override
  Widget build(BuildContext context) {
    final stats = ds.getAdminDashboardStats();
    final wide = _isWide(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _buildHeader(context, stats, user, wide),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 0 : 16,
                  wide ? 16 : 12,
                  wide ? 0 : 16,
                  90,
                ),
                children: [
                  _constrained(context, _buildMetrics(context, stats, wide)),
                  if ((stats['lowStockAlerts'] as int) > 0) ...[
                    SizedBox(height: wide ? 12 : 16),
                    _constrained(context, _buildLowStock(stats, wide)),
                  ],
                  SizedBox(height: wide ? 12 : 16),
                  _constrained(context, _buildStatusChart(context, stats, wide)),
                  SizedBox(height: wide ? 12 : 16),
                  _constrained(context, const SectionHeader(title: 'Pedidos Recentes', icon: Icons.receipt_long, action: 'Ver todos')),
                  _constrained(context, _buildRecentOrders(context, ds, wide)),
                  SizedBox(height: wide ? 12 : 16),
                  _constrained(context, _buildClientCards(context, ds, wide)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext ctx, Map<String, dynamic> stats, AppUser user, bool wide) {
    return Container(
      decoration: AppTheme.headerGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            wide ? 0 : 16,
            wide ? 8 : 12,
            wide ? 0 : 16,
            wide ? 10 : 16,
          ),
          child: _constrained(ctx, Column(
            children: [
              // Título + sino
              Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 0 : 0),
                child: Row(
                  children: [
                    Icon(Icons.warehouse, color: Colors.white, size: wide ? 20 : 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fulfillment Master',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: wide ? 14 : 17,
                                  fontWeight: FontWeight.bold)),
                          Text('Dashboard Administrativo',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: wide ? 10 : 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          if ((stats['lowStockAlerts'] as int) > 0) ...[
                            const Icon(Icons.warning_amber, color: AppTheme.warning, size: 15),
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: AppTheme.warning,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text('${stats['lowStockAlerts']}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 4),
                          ],
                          const NotificationBell(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Mini-stats — só mostra no mobile (no wide já temos os cards abaixo)
              if (!wide) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniStat('Pendentes', '${stats['pendingOrders']}', Icons.pending_actions),
                    const SizedBox(width: 10),
                    _miniStat('Fat. Mês', formatCurrency(stats['monthRevenue']), Icons.attach_money),
                  ],
                ),
              ],
            ],
          )),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(label,
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Metrics grid ─────────────────────────────────────────────────────────

  Widget _buildMetrics(BuildContext context, Map<String, dynamic> stats, bool wide) {
    final items = [
      _MetricItem('Pedidos Hoje', '${stats['todayOrders']}', Icons.today, AppTheme.primary,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
      _MetricItem('Pedidos do Mês', '${stats['monthOrders']}', Icons.calendar_month, AppTheme.info,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
      _MetricItem('Faturamento Mês', formatCurrency(stats['monthRevenue']), Icons.attach_money, Colors.green, null),
      _MetricItem('Em Separação', '${stats['pendingOrders']}', Icons.content_cut, AppTheme.warning, null),
      _MetricItem('Clientes Ativos', '${stats['activeClients']}', Icons.business, Colors.purple, null),
      _MetricItem('Lotes no Armazém', '${stats['totalLots']}', Icons.inventory_2, Colors.teal,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LotsScreen()))),
    ];

    if (wide) {
      // Desktop: 3 colunas, cards compactos em linha
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
        padding: EdgeInsets.zero,
        children: items.map((m) => _MetricCardCompact(item: m)).toList(),
      );
    }

    // Mobile: 2 colunas, cards normais
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4,
      padding: EdgeInsets.zero,
      children: items.map((m) => MetricCard(
        title: m.title,
        value: m.value,
        icon: m.icon,
        color: m.color,
        onTap: m.onTap,
      )).toList(),
    );
  }

  // ── Low stock alert ───────────────────────────────────────────────────────

  Widget _buildLowStock(Map<String, dynamic> stats, bool wide) {
    return Container(
      padding: EdgeInsets.all(wide ? 12 : 14),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, color: AppTheme.warning, size: 16),
            const SizedBox(width: 8),
            Text('${stats['lowStockAlerts']} Alertas de Estoque Baixo',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warning,
                    fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ...(stats['lowStockProducts'] as List<Product>).take(3).map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.circle, size: 5, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('${p.name} (${p.sku})',
                          style: const TextStyle(fontSize: 11))),
                  Text('${ds.getStockByProduct(p.id)}/${p.minimumStock}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w600)),
                ]),
              )),
        ],
      ),
    );
  }

  // ── Status chart ─────────────────────────────────────────────────────────

  Widget _buildStatusChart(BuildContext context, Map<String, dynamic> stats, bool wide) {
    final statusData = stats['ordersByStatus'] as Map<String, int>;
    final total = statusData.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(wide ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status dos Pedidos',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: wide ? 13 : 14)),
          SizedBox(height: wide ? 10 : 16),
          SizedBox(
            height: wide ? 90 : 120,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: OrderStatus.values.asMap().entries.map((e) {
                        final count = statusData[e.value.label] ?? 0;
                        return PieChartSectionData(
                          value: count.toDouble(),
                          color: orderStatusColor(e.value),
                          radius: wide ? 30 : 40,
                          title: count > 0 ? '$count' : '',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        );
                      }).toList(),
                      centerSpaceRadius: wide ? 18 : 24,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Wrap(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  spacing: wide ? 12 : 0,
                  runSpacing: wide ? 4 : 0,
                  children: OrderStatus.values.map((s) {
                    final count = statusData[s.label] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: orderStatusColor(s),
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 4),
                          Text(s.label,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 3),
                          Text('$count',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent orders ─────────────────────────────────────────────────────────

  Widget _buildRecentOrders(BuildContext context, DataService ds, bool wide) {
    final orders = ds.allOrders.take(wide ? 5 : 4).toList();
    if (orders.isEmpty) {
      return const EmptyState(icon: Icons.receipt_long, title: 'Nenhum pedido ainda');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Column(
        children: orders.asMap().entries.map((e) => Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: wide ? 12 : 16, vertical: wide ? 0 : 2),
              leading: Container(
                width: wide ? 30 : 36,
                height: wide ? 30 : 36,
                decoration: BoxDecoration(
                  color: orderStatusColor(e.value.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long,
                    color: orderStatusColor(e.value.status),
                    size: wide ? 15 : 18),
              ),
              title: Text(
                  '${e.value.invoiceNumber} — ${e.value.clientName}',
                  style: TextStyle(
                      fontSize: wide ? 12 : 13,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(formatDateTime(e.value.createdAt),
                  style: TextStyle(fontSize: wide ? 10 : 11)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  orderStatusBadge(e.value.status),
                  const SizedBox(height: 2),
                  Text(formatCurrency(e.value.orderValue),
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (e.key < orders.length - 1)
              const Divider(height: 1, indent: 52),
          ],
        )).toList(),
      ),
    );
  }

  // ── Client cards ──────────────────────────────────────────────────────────

  Widget _buildClientCards(BuildContext context, DataService ds, bool wide) {
    final clients = ds.activeClients;
    if (clients.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SectionHeader(title: 'Clientes Ativos', icon: Icons.business),
        SizedBox(
          height: wide ? 70 : 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: clients.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, i) {
              final c = clients[i];
              final orders = ds
                  .getOrdersByClient(c.id)
                  .where((o) => o.status != OrderStatus.finalizado)
                  .length;
              return Container(
                width: wide ? 160 : 150,
                margin: const EdgeInsets.only(right: 10),
                padding: EdgeInsets.all(wide ? 8 : 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6)
                  ],
                ),
                child: Row(
                  children: [
                    ClientAvatar(
                        initials: c.initials,
                        colorIndex: i,
                        photoUrl: c.photoUrl,
                        size: wide ? 32 : 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.companyName,
                              style: TextStyle(
                                  fontSize: wide ? 11 : 12,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppTheme.primarySurface,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('$orders ped',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Compact metric card (desktop) ─────────────────────────────────────────

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _MetricItem(this.title, this.value, this.icon, this.color, this.onTap);
}

class _MetricCardCompact extends StatelessWidget {
  final _MetricItem item;
  const _MetricCardCompact({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.value,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: item.color)),
                  Text(item.title,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CLIENT DASHBOARD ─────────────────────────────────────────────────────

class _ClientDashboard extends StatelessWidget {
  final DataService ds;
  final AppUser user;
  const _ClientDashboard({required this.ds, required this.user});

  @override
  Widget build(BuildContext context) {
    final clientId = user.clientId ?? '';
    final client = ds.getClient(clientId);
    final orders = ds.getOrdersByClient(clientId);
    final lots = ds.getLotsByClient(clientId);
    final products = ds.getProductsByClient(clientId);
    final activeOrders =
        orders.where((o) => o.status != OrderStatus.finalizado).length;
    final totalStock =
        products.fold(0, (s, p) => s + ds.getStockByProduct(p.id));
    final wide = _isWide(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    wide ? 0 : 16,
                    wide ? 8 : 12,
                    wide ? 0 : 16,
                    wide ? 10 : 16),
                child: _constrained(
                  context,
                  Column(
                    children: [
                      Row(
                        children: [
                          ClientAvatar(
                              initials: client?.initials ?? 'CL',
                              colorIndex: 0,
                              size: wide ? 36 : 44,
                              photoUrl: client?.photoUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(client?.companyName ?? user.name,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: wide ? 14 : 17,
                                        fontWeight: FontWeight.bold)),
                                const Text('Área do Cliente',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          const NotificationBell(),
                        ],
                      ),
                      SizedBox(height: wide ? 8 : 16),
                      Row(
                        children: [
                          _miniStat('Pedidos Ativos', '$activeOrders',
                              Icons.receipt_long),
                          const SizedBox(width: 10),
                          _miniStat('Itens em Estoque', '$totalStock',
                              Icons.inventory_2),
                          const SizedBox(width: 10),
                          _miniStat(
                              'Lotes Ativos', '${lots.length}', Icons.category),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  wide ? 0 : 16, wide ? 16 : 16, wide ? 0 : 16, 24),
              children: [
                if (orders.any((o) =>
                    o.status == OrderStatus.aguardandoSeparacao ||
                    o.status == OrderStatus.separando)) ...[
                  _constrained(
                      context,
                      const SectionHeader(
                          title: 'Pedidos em Andamento',
                          icon: Icons.pending_actions)),
                  ...orders
                      .where((o) =>
                          o.status == OrderStatus.aguardandoSeparacao ||
                          o.status == OrderStatus.separando)
                      .take(3)
                      .map((o) => _constrained(context, _orderTile(context, o))),
                  const SizedBox(height: 16),
                ],
                _constrained(
                    context,
                    const SectionHeader(
                        title: 'Estoque Atual', icon: Icons.inventory)),
                _constrained(
                  context,
                  Container(
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
                      children: products.isEmpty
                          ? [
                              const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Nenhum produto cadastrado',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary)))
                            ]
                          : products.map((p) {
                              final stock = ds.getStockByProduct(p.id);
                              final isLow = stock <= p.minimumStock;
                              return ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isLow
                                        ? AppTheme.errorLight
                                        : AppTheme.primarySurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.inventory_2,
                                      size: 16,
                                      color: isLow
                                          ? AppTheme.error
                                          : AppTheme.primary),
                                ),
                                title: Text(p.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(p.sku,
                                    style: const TextStyle(fontSize: 11)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('$stock unid.',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isLow
                                                ? AppTheme.error
                                                : AppTheme.primary)),
                                    if (isLow)
                                      const Text('Estoque baixo!',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.error)),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: orderStatusColor(order.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long,
                color: orderStatusColor(order.status), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.invoiceNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(formatDateTime(order.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          orderStatusBadge(order.status),
        ],
      ),
    );
  }
}
