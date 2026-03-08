// lib/screens/orders/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../notifications/notifications_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    // Atendente de suporte: acesso somente leitura (sem criar/importar pedidos)
    final isReadOnly = ds.isSupportAgent;
    final allOrders = isReadOnly
        ? ([...ds.allOrders]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        : ds.currentClientOrders;

    final pending = allOrders.where((o) => o.status == OrderStatus.aguardandoSeparacao || o.status == OrderStatus.separando).toList();
    final active = allOrders.where((o) => o.status == OrderStatus.faturado || o.status == OrderStatus.enviado).toList();
    final done = allOrders.where((o) => o.status == OrderStatus.finalizado).toList();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
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
                          const SizedBox(width: 12),
                        const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Gestão de Pedidos', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                        // Ocultar ações de edição para atendente (somente leitura)
                        if (!isReadOnly) ...[
                          // Importar múltiplos XMLs (admin, operador E cliente)
                          IconButton(
                            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                            tooltip: 'Importar XMLs em lote',
                            onPressed: () => _showBatchXmlImport(context, ds),
                          ),
                          // Clientes também podem criar pedidos
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                            onPressed: () => _showNewOrderDialog(context, ds),
                          ),
                        ],
                        const NotificationBell(),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tab,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: 'Pendentes (${pending.length})'),
                      Tab(text: 'Em Curso (${active.length})'),
                      Tab(text: 'Finalizados (${done.length})'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por NF ou cliente...',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OrderList(orders: _filter(pending), ds: ds, emptyMsg: 'Nenhum pedido pendente'),
                _OrderList(orders: _filter(active), ds: ds, emptyMsg: 'Nenhum pedido em curso'),
                _OrderList(orders: _filter(done), ds: ds, emptyMsg: 'Nenhum pedido finalizado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Order> _filter(List<Order> list) {
    if (_search.isEmpty) return list;
    return list.where((o) =>
      o.invoiceNumber.toLowerCase().contains(_search) ||
      o.clientName.toLowerCase().contains(_search)
    ).toList();
  }

  void _showNewOrderDialog(BuildContext context, DataService ds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NewOrderSheet(ds: ds),
    );
  }

  void _showBatchXmlImport(BuildContext context, DataService ds) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => _BatchXmlImportScreen(ds: ds)),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final DataService ds;
  final String emptyMsg;

  const _OrderList({required this.orders, required this.ds, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(icon: Icons.receipt_long, title: emptyMsg);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: orders.length,
      itemBuilder: (context, i) => _OrderCard(order: orders[i], ds: ds),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final DataService ds;
  const _OrderCard({required this.order, required this.ds});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(order.clientName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      orderStatusBadge(order.status),
                      const SizedBox(height: 4),
                      orderSizeBadge(order.size),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${order.items.length} produto(s)', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(formatDateTime(order.createdAt), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text(formatCurrency(order.orderValue),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14)),
                ],
              ),
              if (order.status == OrderStatus.aguardandoSeparacao || order.status == OrderStatus.separando) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                const Text('Tarefas de Separação', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                ...order.separationTasks.take(2).map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(t.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 14, color: t.isCompleted ? AppTheme.success : AppTheme.textHint),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${t.productName} (${t.quantity} un.) — ${t.addressCode}',
                        style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                )),
              ],
              // Status stepper
              const SizedBox(height: 10),
              OrderStatusStepper(currentStatus: order.status),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ORDER DETAIL SCREEN ──────────────────────────────────────────────────

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

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
    final order = ds.getOrder(widget.orderId);
    if (order == null) return const Scaffold(body: Center(child: Text('Pedido não encontrado')));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // Header com TabBar integrado
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pedido ${order.invoiceNumber}',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(order.clientName,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            orderStatusBadge(order.status),
                            const SizedBox(width: 6),
                            orderSizeBadge(order.size),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TabBar(
                    controller: _tab,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(icon: Icon(Icons.info_outline, size: 16), text: 'Detalhes'),
                      Tab(icon: Icon(Icons.history, size: 16), text: 'Histórico'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // ── ABA DETALHES ──────────────────────────────────────────
                _OrderDetailsTab(order: order, ds: ds),
                // ── ABA HISTÓRICO ─────────────────────────────────────────
                _OrderHistoryTab(order: order),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget de Detalhes do Pedido ──────────────────────────────────────────

class _OrderDetailsTab extends StatelessWidget {
  final Order order;
  final DataService ds;
  const _OrderDetailsTab({required this.order, required this.ds});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
                // Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            orderStatusBadge(order.status),
                            const SizedBox(width: 8),
                            orderSizeBadge(order.size),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OrderStatusStepper(currentStatus: order.status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Informações do Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(height: 16),
                        InfoRow(label: 'Nota Fiscal', value: order.invoiceNumber, icon: Icons.receipt),
                        InfoRow(label: 'Cliente', value: order.clientName, icon: Icons.business),
                        InfoRow(label: 'Data de Entrada', value: formatDateTime(order.createdAt), icon: Icons.schedule),
                        InfoRow(label: 'Valor', value: formatCurrency(order.orderValue), icon: Icons.attach_money, valueColor: AppTheme.primary),
                        InfoRow(label: 'Tamanho', value: order.size.label, icon: Icons.straighten),
                        const Divider(height: 16),
                        // ── Chave de Acesso NF-e (sempre visível) ─────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.key, size: 16,
                                color: order.accessKey.isNotEmpty ? AppTheme.primary : AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Chave de Acesso NF-e',
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 4),
                                  if (order.accessKey.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning_amber, size: 15, color: AppTheme.warning),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Chave não informada neste pedido',
                                              style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySurface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: SelectableText(
                                        order.accessKey,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                          letterSpacing: 0.5,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            final key = order.accessKey;
                                            final chunks = <String>[];
                                            for (var i = 0; i < key.length; i += 4) {
                                              chunks.add(key.substring(i, i + 4 > key.length ? key.length : i + 4));
                                            }
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Chave copiada! ${chunks.join(' ')}'),
                                                backgroundColor: AppTheme.success,
                                                duration: const Duration(seconds: 4),
                                                action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.copy, size: 13, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text('Copiar',
                                                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Consulte em consultadanfe.com.br ou portal SEFAZ',
                                            style: TextStyle(fontSize: 10, color: AppTheme.textHint),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Items
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Itens do Pedido (${order.items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(height: 16),
                        ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.inventory_2, size: 16, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('SKU: ${item.sku}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Text('${item.separatedQuantity}/${item.quantity} un.',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                  color: item.isFullySeparated ? AppTheme.success : AppTheme.warning)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Separation tasks
                if (order.separationTasks.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tarefas de Separação', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Text('(Ordem FIFO automática)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const Divider(height: 16),
                          ...order.separationTasks.map((t) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: t.isCompleted ? AppTheme.successLight : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.isCompleted ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                Icon(t.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: t.isCompleted ? AppTheme.success : AppTheme.textHint),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 12, color: AppTheme.primary),
                                          Text(' ${t.addressCode}', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.qr_code, size: 12, color: AppTheme.info),
                                          Text(' Lote: ${t.lotBarcode}', style: const TextStyle(fontSize: 11, color: AppTheme.info)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text('${t.quantity} un.', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Action buttons
                if (ds.isAdmin || ds.isOperator) _buildActions(context, ds, order),
                const SizedBox(height: 20),
              ],
            );
  }

  Widget _buildActions(BuildContext context, DataService ds, Order order) {
    return Column(
      children: [
        if (order.status == OrderStatus.aguardandoSeparacao)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.content_cut),
              label: const Text('Iniciar Separação'),
              onPressed: () async {
                await ds.updateOrderStatus(order.id, OrderStatus.separando);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        if (order.status == OrderStatus.separando) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Finalizar Separação'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              onPressed: () async {
                await ds.completeSeparation(order.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ],
        if (order.status == OrderStatus.faturado)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.local_shipping),
              label: const Text('Marcar como Enviado'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
              onPressed: () async {
                await ds.updateOrderStatus(order.id, OrderStatus.enviado);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        if (order.status == OrderStatus.enviado)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.done_all),
              label: const Text('Finalizar Pedido'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusFinalizado),
              onPressed: () async {
                await ds.updateOrderStatus(order.id, OrderStatus.finalizado);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
      ],
    );
  }
}

// ── Widget de Histórico do Pedido ─────────────────────────────────────────

class _OrderHistoryTab extends StatelessWidget {
  final Order order;
  const _OrderHistoryTab({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: AppTheme.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Nenhum evento registrado', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('O histórico aparecerá aqui conforme o pedido avançar.',
                style: TextStyle(color: AppTheme.textHint, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final events = order.events.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final ev = events[i];
        final isLast = i == events.length - 1;
        return _TimelineEventRow(event: ev, isLast: isLast);
      },
    );
  }
}

// ── Timeline Event Row visual aprimorado ──────────────────────────────────

class _TimelineEventRow extends StatelessWidget {
  final OrderEvent event;
  final bool isLast;
  const _TimelineEventRow({required this.event, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(event.action);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
                ),
                child: Icon(_actionIcon(event.action), size: 17, color: color),
              ),
              if (!isLast)
                Container(width: 2, height: 40, color: AppTheme.divider),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.description,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(event.userName,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 13, color: AppTheme.textHint),
                      const SizedBox(width: 3),
                      Text(formatDateTime(event.date),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'criado': return Icons.add_circle_outline;
      case 'separacao_iniciada': return Icons.content_cut;
      case 'separacao_concluida': return Icons.check_circle_outline;
      case 'faturado': return Icons.receipt;
      case 'enviado': return Icons.local_shipping;
      case 'finalizado': return Icons.done_all;
      default: return Icons.update;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'criado': return AppTheme.info;
      case 'separacao_iniciada': return AppTheme.warning;
      case 'separacao_concluida': return AppTheme.success;
      case 'faturado': return AppTheme.primary;
      case 'enviado': return Colors.indigo;
      case 'finalizado': return AppTheme.statusFinalizado;
      default: return AppTheme.textSecondary;
    }
  }
}



// ─── NEW ORDER SHEET ──────────────────────────────────────────────────────
// Suporta dois modos: Manual (seleção de produtos) e XML (NF de venda)

class _NewOrderSheet extends StatefulWidget {
  final DataService ds;
  const _NewOrderSheet({required this.ds});
  @override
  State<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends State<_NewOrderSheet> {
  final _nfCtrl = TextEditingController();
  final _accessKeyCtrl = TextEditingController();
  String? _selectedClientId;
  String _mode = 'manual'; // 'manual' ou 'xml'
  bool _loading = false;
  bool _xmlLoaded = false;
  OrderSize? _selectedSize; // null = automático

  // Lista de itens do pedido
  final List<_OrderEntry> _entries = [];

  // Itens não identificados no XML
  final List<NfeItem> _unmatched = [];

  @override
  void initState() {
    super.initState();
    if (widget.ds.isClient && widget.ds.currentClientId != null) {
      _selectedClientId = widget.ds.currentClientId;
    }
  }

  @override
  void dispose() {
    _nfCtrl.dispose();
    _accessKeyCtrl.dispose();
    super.dispose();
  }

  // Carrega XML real via FilePicker
  Future<void> _loadXml() async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um cliente primeiro')));
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final xmlContent = String.fromCharCodes(bytes);

    final parsed = DataService.parseNfeXml(xmlContent);
    if (parsed.hasError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(parsed.error!), backgroundColor: AppTheme.error));
      }
      return;
    }

    _applyParsedXml(parsed);
  }

  void _applyParsedXml(NfeParseResult parsed) {
    final matched = <_OrderEntry>[];
    final unmatched = <NfeItem>[];

    for (final item in parsed.items) {
      final product = widget.ds.getProductByEanOrCode(
          _selectedClientId!, item.cEAN, item.cProd);
      if (product != null) {
        matched.add(_OrderEntry(
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          quantity: item.quantity,
        ));
      } else {
        unmatched.add(item);
      }
    }

    setState(() {
      _entries.clear();
      _entries.addAll(matched);
      _unmatched.clear();
      _unmatched.addAll(unmatched);
      if (parsed.invoiceNumber.isNotEmpty) {
        _nfCtrl.text = parsed.invoiceNumber;
      }
      if (parsed.accessKey.isNotEmpty) {
        _accessKeyCtrl.text = parsed.accessKey;
      }
      _xmlLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clients = widget.ds.activeClients;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_shopping_cart, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Novo Pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('NF de saída / pedido de separação', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cliente — se for cliente, exibe apenas o nome; senão, dropdown
            if (widget.ds.isClient)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cliente', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text(
                            clients.firstWhere((c) => c.id == _selectedClientId,
                              orElse: () => clients.first).companyName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline, size: 16, color: AppTheme.textHint),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Cliente *', prefixIcon: Icon(Icons.business, size: 18)),
                initialValue: _selectedClientId,
                items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.companyName))).toList(),
                onChanged: (v) => setState(() {
                  _selectedClientId = v;
                  _entries.clear();
                  _xmlLoaded = false;
                }),
              ),
            const SizedBox(height: 12),

            // Número NF
            TextField(
              controller: _nfCtrl,
              decoration: const InputDecoration(
                labelText: 'Número da NF de Venda',
                hintText: 'Ex: NFV-001234 (opcional)',
                prefixIcon: Icon(Icons.receipt, size: 18),
              ),
            ),
            const SizedBox(height: 10),

            // Chave de acesso NF-e (obrigatório)
            TextField(
              controller: _accessKeyCtrl,
              keyboardType: TextInputType.number,
              maxLength: 44,
              decoration: InputDecoration(
                labelText: 'Chave de Acesso NF-e *',
                hintText: '44 dígitos (obrigatório)',
                prefixIcon: const Icon(Icons.key, size: 18),
                helperText: 'Use para consultar a NF-e no Consulta DANFE ou SEFAZ',
                counterStyle: TextStyle(
                  color: _accessKeyCtrl.text.replaceAll(RegExp(r'\D'), '').length == 44
                      ? AppTheme.success
                      : AppTheme.textSecondary,
                  fontSize: 11,
                ),
                suffixIcon: _accessKeyCtrl.text.replaceAll(RegExp(r'\D'), '').length == 44
                    ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),

            // ── Tipo de embalagem ──────────────────────────────────────────
            const Text('Tipo de embalagem',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text(
              'Automático: calculado pelo tamanho dos produtos. Manual: força o tipo escolhido.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sizeChip(null, Icons.auto_fix_high, 'Automático'),
                ...OrderSize.values.map((s) => _sizeChip(s, s.icon, s.label)),
              ],
            ),
            const SizedBox(height: 16),

            // Seleção de modo
            const Text('Modo de entrada de itens',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _modeCard(
                  icon: Icons.edit_note,
                  title: 'Manual',
                  subtitle: 'Selecionar produtos e quantidades',
                  value: 'manual',
                )),
                const SizedBox(width: 10),
                Expanded(child: _modeCard(
                  icon: Icons.upload_file,
                  title: 'XML / NF-e',
                  subtitle: 'Importar nota fiscal XML',
                  value: 'xml',
                )),
              ],
            ),

            // Botão carregar XML
            if (_mode == 'xml') ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _loadXml,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _xmlLoaded ? AppTheme.successLight : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _xmlLoaded ? AppTheme.success : AppTheme.primary,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(_xmlLoaded ? Icons.check_circle : Icons.upload_file,
                          size: 32,
                          color: _xmlLoaded ? AppTheme.success : AppTheme.primary),
                      const SizedBox(height: 6),
                      Text(
                        _xmlLoaded
                            ? 'XML carregado — ${_entries.length} produto(s) identificado(s)'
                            : 'Toque para selecionar XML da NF-e',
                        style: TextStyle(
                            color: _xmlLoaded ? AppTheme.success : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      if (!_xmlLoaded) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Suporta arquivos .xml de NF-e\nO número da nota e produtos serão preenchidos automaticamente',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Produtos não identificados
              if (_xmlLoaded && _unmatched.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          '${_unmatched.length} produto(s) não identificado(s)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      const Text(
                        'Cadastre o EAN ou Código NF-e nos produtos para identificá-los:',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      ..._unmatched.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          const Icon(Icons.circle, size: 6, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            '${item.xProd} (cProd: ${item.cProd}${item.cEAN.isNotEmpty ? ' / EAN: ${item.cEAN}' : ''})',
                            style: const TextStyle(fontSize: 11),
                          )),
                        ]),
                      )),
                    ],
                  ),
                ),
              ],
            ],

            // Lista de itens adicionados
            if (_entries.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text('${_entries.length} produto(s) no pedido',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    ..._entries.asMap().entries.map((e) {
                      final idx = e.key;
                      final entry = e.value;
                      return Column(
                        children: [
                          const Divider(height: 1, indent: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color: AppTheme.primarySurface,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.inventory_2, size: 15, color: AppTheme.primary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.productName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('SKU: ${entry.sku}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                // Controle +/-
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _qtyBtn(Icons.remove, () {
                                      if (entry.quantity > 1) {
                                        setState(() => _entries[idx] = entry.withQty(entry.quantity - 1));
                                      }
                                    }),
                                    Container(
                                      width: 40,
                                      alignment: Alignment.center,
                                      child: Text('${entry.quantity}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                    _qtyBtn(Icons.add, () =>
                                        setState(() => _entries[idx] = entry.withQty(entry.quantity + 1))),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(() => _entries.removeAt(idx)),
                                  tooltip: 'Remover',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],

            // Painel de adicionar produto (só no modo manual)
            if (_mode == 'manual' && _selectedClientId != null) ...[
              const SizedBox(height: 14),
              _AddItemPanel(
                products: widget.ds.getProductsByClient(_selectedClientId!),
                alreadyAdded: _entries.map((e) => e.productId).toList(),
                onAdd: (productId, productName, sku, qty) {
                  setState(() {
                    final existing = _entries.indexWhere((e) => e.productId == productId);
                    if (existing >= 0) {
                      _entries[existing] = _entries[existing].withQty(_entries[existing].quantity + qty);
                    } else {
                      _entries.add(_OrderEntry(productId: productId, productName: productName, sku: sku, quantity: qty));
                    }
                  });
                },
              ),
            ],

            const SizedBox(height: 20),

            // Botão criar pedido
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_shopping_cart),
                label: Text(_loading ? 'Criando pedido...' : 'Criar Pedido — ${_entries.length} produto(s)'),
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      !_loading &&
      _selectedClientId != null &&
      _entries.isNotEmpty &&
      _accessKeyCtrl.text.replaceAll(RegExp(r'\D'), '').length == 44;

  Widget _modeCard({required IconData icon, required String title, required String subtitle, required String value}) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() {
        _mode = value;
        _xmlLoaded = false;
        if (value == 'manual') _entries.clear();
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.divider, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: selected ? AppTheme.primary : AppTheme.textSecondary, size: 20),
                const Spacer(),
                if (selected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? AppTheme.primary : AppTheme.textPrimary, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 15, color: AppTheme.primary),
      ),
    );
  }

  Widget _sizeChip(OrderSize? size, IconData icon, String label) {
    final selected = _selectedSize == size;
    return GestureDetector(
      onTap: () => setState(() => _selectedSize = size),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedClientId == null || _entries.isEmpty) return;
    final cleanKey = _accessKeyCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cleanKey.length != 44) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informe a chave de acesso com 44 dígitos'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final nf = _nfCtrl.text.isNotEmpty
          ? _nfCtrl.text
          : 'NFV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final orderItems = _entries.map((e) => OrderItem(
        productId: e.productId,
        productName: e.productName,
        sku: e.sku,
        quantity: e.quantity,
      )).toList();

      await widget.ds.createOrderFromXml(
        clientId: _selectedClientId!,
        invoiceNumber: nf,
        accessKey: cleanKey,
        items: orderItems,
        manualSize: _selectedSize,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pedido criado com sucesso!'),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Entrada de item de pedido ────────────────────────────────────────────────

class _OrderEntry {
  final String productId;
  final String productName;
  final String sku;
  final int quantity;

  const _OrderEntry({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
  });

  _OrderEntry withQty(int qty) =>
      _OrderEntry(productId: productId, productName: productName, sku: sku, quantity: qty);
}

// ── Painel de adicionar produto ao pedido ────────────────────────────────────

class _AddItemPanel extends StatefulWidget {
  final List<Product> products;
  final List<String> alreadyAdded;
  final void Function(String productId, String productName, String sku, int qty) onAdd;

  const _AddItemPanel({required this.products, required this.alreadyAdded, required this.onAdd});

  @override
  State<_AddItemPanel> createState() => _AddItemPanelState();
}

class _AddItemPanelState extends State<_AddItemPanel> {
  String? _selectedProductId;
  int _qty = 1;
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.warningLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4))),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text('Nenhum produto cadastrado para este cliente.',
                  style: TextStyle(fontSize: 12, color: AppTheme.warning)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Adicionar produto ao pedido',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdown de produto
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Produto *', prefixIcon: Icon(Icons.inventory_2, size: 18)),
            initialValue: _selectedProductId,
            hint: const Text('Selecione um produto'),
            items: widget.products.map((p) {
              final alreadyIn = widget.alreadyAdded.contains(p.id);
              return DropdownMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.name, style: TextStyle(fontSize: 13, color: alreadyIn ? AppTheme.textSecondary : AppTheme.textPrimary)),
                          Text('SKU: ${p.sku}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (alreadyIn)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedProductId = v),
          ),
          const SizedBox(height: 12),

          // Quantidade
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade *',
                    prefixIcon: Icon(Icons.numbers, size: 18),
                    suffixText: 'un.',
                  ),
                  onChanged: (v) => setState(() => _qty = int.tryParse(v) ?? 1),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  _qtyBtn(Icons.add, () => setState(() { _qty++; _qtyCtrl.text = '$_qty'; })),
                  const SizedBox(height: 6),
                  _qtyBtn(Icons.remove, () {
                    if (_qty > 1) setState(() { _qty--; _qtyCtrl.text = '$_qty'; });
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(_selectedProductId != null && widget.alreadyAdded.contains(_selectedProductId)
                  ? 'Atualizar quantidade'
                  : 'Adicionar ao pedido'),
              onPressed: _selectedProductId != null && _qty > 0 ? _add : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 17, color: AppTheme.primary),
      ),
    );
  }

  void _add() {
    final product = widget.products.firstWhere((p) => p.id == _selectedProductId);
    widget.onAdd(product.id, product.name, product.sku, _qty);
    setState(() {
      _selectedProductId = null;
      _qty = 1;
      _qtyCtrl.text = '1';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${product.name} adicionado — $_qty un.'),
      backgroundColor: AppTheme.primary,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─── BATCH XML IMPORT SCREEN ─────────────────────────────────────────────────

class _BatchXmlImportScreen extends StatefulWidget {
  final DataService ds;
  const _BatchXmlImportScreen({required this.ds});
  @override
  State<_BatchXmlImportScreen> createState() => _BatchXmlImportScreenState();
}

class _XmlBatchEntry {
  final String fileName;
  final NfeParseResult parsed;
  String? selectedClientId;
  bool willCreate;
  List<_OrderEntry> matched;
  List<NfeItem> unmatched;
  // Erros detectados nesta entrada
  List<String> errors;

  _XmlBatchEntry({
    required this.fileName,
    required this.parsed,
    required this.selectedClientId,
    this.willCreate = true,
    required this.matched,
    required this.unmatched,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty || parsed.hasError;
  bool get canCreate => !hasErrors && selectedClientId != null && matched.isNotEmpty;
}

class _BatchXmlImportScreenState extends State<_BatchXmlImportScreen> {
  final List<_XmlBatchEntry> _entries = [];
  bool _importing = false;
  bool _done = false;
  int _created = 0;
  final Map<String, String?> _results = {};

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final newEntries = <_XmlBatchEntry>[];
    for (final f in result.files) {
      if (f.bytes == null) continue;
      final xmlContent = String.fromCharCodes(f.bytes!);
      final parsed = DataService.parseNfeXml(xmlContent);
      final errors = <String>[];

      if (parsed.hasError) {
        errors.add('Erro ao ler arquivo XML: ${parsed.error}');
        newEntries.add(_XmlBatchEntry(
          fileName: f.name, parsed: parsed, selectedClientId: null,
          willCreate: false, matched: [], unmatched: [], errors: errors,
        ));
        continue;
      }

      String? clientId;
      if (parsed.clientCnpj.isNotEmpty) {
        final digits = parsed.clientCnpj.replaceAll(RegExp(r'\D'), '');
        final client = widget.ds.clients.where((c) {
          final cDigits = c.cnpjCpf.replaceAll(RegExp(r'\D'), '');
          return cDigits == digits;
        }).firstOrNull;
        clientId = client?.id;
        if (clientId == null) {
          errors.add('Cliente não encontrado — CNPJ/CPF: ${_formatCnpj(parsed.clientCnpj)} (${parsed.clientName})');
        }
      } else {
        errors.add('Não foi possível identificar o cliente (CNPJ/CPF ausente na nota)');
      }

      if (parsed.accessKey.isEmpty) {
        errors.add('Chave de acesso não encontrada no XML');
      }

      final matched = <_OrderEntry>[];
      final unmatched = <NfeItem>[];
      if (clientId != null) {
        for (final item in parsed.items) {
          final product = widget.ds.getProductByEanOrCode(clientId, item.cEAN, item.cProd);
          if (product != null) {
            matched.add(_OrderEntry(productId: product.id, productName: product.name, sku: product.sku, quantity: item.quantity));
          } else {
            unmatched.add(item);
            errors.add('Produto não cadastrado: "${item.xProd}" (cProd: ${item.cProd}${item.cEAN.isNotEmpty ? ", EAN: ${item.cEAN}" : ""})');
          }
        }
      }

      if (matched.isEmpty && clientId != null) {
        errors.add('Nenhum produto da nota foi identificado no cadastro');
      }

      newEntries.add(_XmlBatchEntry(
        fileName: f.name, parsed: parsed, selectedClientId: clientId,
        willCreate: errors.isEmpty, matched: matched, unmatched: unmatched, errors: errors,
      ));
    }
    setState(() => _entries.addAll(newEntries));
  }

  String _formatCnpj(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 14) return '${d.substring(0,2)}.${d.substring(2,5)}.${d.substring(5,8)}/${d.substring(8,12)}-${d.substring(12)}';
    if (d.length == 11) return '${d.substring(0,3)}.${d.substring(3,6)}.${d.substring(6,9)}-${d.substring(9)}';
    return raw;
  }

  void _resolveProducts(_XmlBatchEntry entry) {
    if (entry.selectedClientId == null) return;
    final matched = <_OrderEntry>[];
    final unmatched = <NfeItem>[];
    final errors = <String>[];

    if (entry.parsed.accessKey.isEmpty) {
      errors.add('Chave de acesso não encontrada no XML');
    }

    for (final item in entry.parsed.items) {
      final product = widget.ds.getProductByEanOrCode(entry.selectedClientId!, item.cEAN, item.cProd);
      if (product != null) {
        matched.add(_OrderEntry(productId: product.id, productName: product.name, sku: product.sku, quantity: item.quantity));
      } else {
        unmatched.add(item);
        errors.add('Produto não cadastrado: "${item.xProd}" (cProd: ${item.cProd}${item.cEAN.isNotEmpty ? ", EAN: ${item.cEAN}" : ""})');
      }
    }

    if (matched.isEmpty) errors.add('Nenhum produto da nota foi identificado no cadastro');

    setState(() {
      entry.matched = matched;
      entry.unmatched = unmatched;
      entry.errors.clear();
      entry.errors.addAll(errors);
      entry.willCreate = errors.isEmpty;
    });
  }

  Future<void> _importAll() async {
    setState(() { _importing = true; _created = 0; _results.clear(); });
    int count = 0;
    for (final entry in _entries) {
      if (!entry.willCreate) {
        _results[entry.fileName] = entry.errors.isNotEmpty ? entry.errors.first : 'Desativado manualmente';
        continue;
      }
      if (entry.selectedClientId == null) { _results[entry.fileName] = 'Cliente não identificado'; continue; }
      if (entry.matched.isEmpty) { _results[entry.fileName] = 'Nenhum produto identificado'; continue; }
      try {
        await widget.ds.createOrderFromXml(
          clientId: entry.selectedClientId!,
          invoiceNumber: entry.parsed.invoiceNumber.isNotEmpty ? entry.parsed.invoiceNumber : 'XML-${DateTime.now().millisecondsSinceEpoch}',
          accessKey: entry.parsed.accessKey,
          items: entry.matched.map((e) => OrderItem(productId: e.productId, productName: e.productName, sku: e.sku, quantity: e.quantity)).toList(),
        );
        _results[entry.fileName] = null;
        count++;
      } catch (e) {
        _results[entry.fileName] = 'Erro ao criar pedido: $e';
      }
    }
    setState(() { _importing = false; _done = true; _created = count; });
  }

  @override
  Widget build(BuildContext context) {
    final readyCount = _entries.where((e) => e.willCreate && e.canCreate).length;
    final errorCount = _entries.where((e) => e.hasErrors).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Icon(Icons.file_upload_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Importar XMLs em Lote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (_entries.isNotEmpty)
                        Text('$readyCount pronto${readyCount != 1 ? "s" : ""} • $errorCount com erro${errorCount != 1 ? "s" : ""}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11))
                      else
                        const Text('Cria múltiplos pedidos de uma vez', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: _done
                ? _DoneView(created: _created, results: _results, onBack: () => Navigator.pop(context))
                : _entries.isEmpty
                    ? _EmptyPickView(onPick: _pickFiles)
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Adicionar mais XMLs'), onPressed: _pickFiles),
                          const SizedBox(height: 12),
                          ..._entries.map((entry) => _XmlEntryCard(
                            entry: entry, ds: widget.ds,
                            onClientChanged: (id) { setState(() => entry.selectedClientId = id); _resolveProducts(entry); },
                            onToggle: (v) => setState(() => entry.willCreate = v),
                            onRemove: () => setState(() => _entries.remove(entry)),
                          )),
                          const SizedBox(height: 16),
                          if (errorCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.warning_amber, color: AppTheme.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(
                                  '$errorCount XML${errorCount != 1 ? "s" : ""} com problema — verifique os itens em vermelho acima.',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.error),
                                )),
                              ]),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (readyCount > 0)
                            ElevatedButton.icon(
                              icon: _importing
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.rocket_launch, color: Colors.white),
                              label: Text(
                                _importing ? 'Criando pedidos...' : 'Criar $readyCount Pedido${readyCount > 1 ? "s" : ""}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: _importing ? null : _importAll,
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPickView extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyPickView({required this.onPick});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.folder_open, size: 64, color: AppTheme.primary),
        const SizedBox(height: 16),
        const Text('Nenhum XML carregado',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Selecione um ou mais arquivos XML de NF-e',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file, color: Colors.white),
          label: const Text('Selecionar XMLs', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: onPick,
        ),
      ]),
    );
  }
}

class _DoneView extends StatelessWidget {
  final int created;
  final Map<String, String?> results;
  final VoidCallback onBack;
  const _DoneView({required this.created, required this.results, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final errors = results.entries.where((e) => e.value != null).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        Icon(
          created > 0 ? Icons.check_circle : Icons.error_outline,
          size: 72,
          color: created > 0 ? AppTheme.success : AppTheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          '$created pedido${created != 1 ? 's' : ''} criado${created != 1 ? 's' : ''} com sucesso!',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (created > 0)
          const Text(
            'Os pedidos foram adicionados à fila de separação.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        // Erros por arquivo
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${errors.length} arquivo${errors.length != 1 ? 's' : ''} com problema',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.error),
                  ),
                ]),
                const SizedBox(height: 12),
                ...errors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          e.key,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        )),
                      ]),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e.value ?? '',
                          style: const TextStyle(fontSize: 12, color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 4),
                const Text(
                  'Dica: Cadastre o EAN ou cProd do produto e o CNPJ do cliente correspondente.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onBack,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Ver Pedidos', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _XmlEntryCard extends StatelessWidget {
  final _XmlBatchEntry entry;
  final DataService ds;
  final void Function(String?) onClientChanged;
  final void Function(bool) onToggle;
  final VoidCallback onRemove;
  const _XmlEntryCard({
    required this.entry, required this.ds,
    required this.onClientChanged, required this.onToggle, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canCreate = entry.canCreate;
    final hasErrors = entry.hasErrors;
    final borderColor = canCreate ? AppTheme.success : hasErrors ? AppTheme.error : AppTheme.divider;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: (canCreate || hasErrors) ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Row(children: [
            Icon(
              hasErrors ? Icons.error_outline : Icons.description_outlined,
              size: 18,
              color: canCreate ? AppTheme.success : hasErrors ? AppTheme.error : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                if (entry.parsed.invoiceNumber.isNotEmpty)
                  Text('NF-e no ${entry.parsed.invoiceNumber}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                if (entry.parsed.invoiceNumber.isNotEmpty && entry.parsed.accessKey.isNotEmpty)
                  const Text(' - ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                if (entry.parsed.accessKey.isNotEmpty)
                  Flexible(child: Text('Chave: ${entry.parsed.accessKey.substring(0, 8)}...',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            Switch(
              value: entry.willCreate && !hasErrors,
              onChanged: hasErrors ? null : onToggle,
              activeThumbColor: AppTheme.primary,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
              onPressed: onRemove,
            ),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            DropdownButtonFormField<String>(
              initialValue: entry.selectedClientId,
              decoration: const InputDecoration(
                labelText: 'Cliente',
                prefixIcon: Icon(Icons.business_outlined, size: 18),
                isDense: true,
              ),
              items: ds.clients.map((c) => DropdownMenuItem(
                value: c.id, child: Text(c.companyName, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: onClientChanged,
            ),
            const SizedBox(height: 10),
            if (entry.errors.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.report_problem_outlined, size: 14, color: AppTheme.error),
                    SizedBox(width: 6),
                    Text('Problemas encontrados:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error)),
                  ]),
                  const SizedBox(height: 6),
                  ...entry.errors.map((err) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle, size: 5, color: AppTheme.error),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(err, style: const TextStyle(fontSize: 11, color: AppTheme.error))),
                    ]),
                  )),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            if (entry.matched.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${entry.matched.length} produto(s) identificado(s)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success),
                  ),
                  const SizedBox(height: 4),
                  ...entry.matched.map((e) => Text(
                    '- ${e.productName} - ${e.quantity} un',
                    style: const TextStyle(fontSize: 11),
                  )),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
