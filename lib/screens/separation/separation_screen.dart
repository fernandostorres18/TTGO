// lib/screens/separation/separation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class SeparationScreen extends StatefulWidget {
  const SeparationScreen({super.key});
  @override
  State<SeparationScreen> createState() => _SeparationScreenState();
}

class _SeparationScreenState extends State<SeparationScreen> with SingleTickerProviderStateMixin {
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
    final pendingOrders = ds.allOrders.where((o) =>
      o.status == OrderStatus.aguardandoSeparacao || o.status == OrderStatus.separando).toList();

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
                        const Icon(Icons.content_cut, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Separação de Pedidos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Bipagem + Validação + FIFO Automático', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text('${pendingOrders.length} pendentes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tab,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    tabs: const [
                      Tab(text: 'Fila de Separação'),
                      Tab(text: 'Scanner'),
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
                _SeparationQueueTab(ds: ds, pendingOrders: pendingOrders),
                _ScannerTab(ds: ds),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QUEUE TAB ─────────────────────────────────────────────────────────────

class _SeparationQueueTab extends StatelessWidget {
  final DataService ds;
  final List<Order> pendingOrders;

  const _SeparationQueueTab({required this.ds, required this.pendingOrders});

  @override
  Widget build(BuildContext context) {
    if (pendingOrders.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle,
        title: 'Fila vazia!',
        subtitle: 'Todos os pedidos foram separados.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingOrders.length,
      itemBuilder: (context, i) => _SeparationOrderCard(order: pendingOrders[i], ds: ds),
    );
  }
}

class _SeparationOrderCard extends StatelessWidget {
  final Order order;
  final DataService ds;

  const _SeparationOrderCard({required this.order, required this.ds});

  @override
  Widget build(BuildContext context) {
    final completedTasks = order.separationTasks.where((t) => t.isCompleted).length;
    final totalTasks = order.separationTasks.length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    final isInProgress = order.status == OrderStatus.separando;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isInProgress ? AppTheme.infoLight : AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(isInProgress ? Icons.content_cut : Icons.schedule,
                    color: isInProgress ? AppTheme.info : AppTheme.warning, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(order.clientName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    orderStatusBadge(order.status),
                    const SizedBox(height: 4),
                    Text('$completedTasks/$totalTasks tarefas', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progresso', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.divider,
                    valueColor: AlwaysStoppedAnimation(progress >= 1 ? AppTheme.success : AppTheme.primary),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Tasks preview
            ...order.separationTasks.take(3).map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(t.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 14, color: t.isCompleted ? AppTheme.success : AppTheme.textHint),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${t.productName} (${t.quantity} un.)', style: const TextStyle(fontSize: 11))),
                  const Icon(Icons.location_on, size: 11, color: AppTheme.primary),
                  Text(' ${t.addressCode}', style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            )),
            if (order.separationTasks.length > 3)
              Text('+${order.separationTasks.length - 3} mais...', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Row(
              children: [
                if (!isInProgress)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Iniciar Separação'),
                      onPressed: () async {
                        await ds.updateOrderStatus(order.id, OrderStatus.separando);
                      },
                    ),
                  ),
                if (isInProgress) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      label: const Text('Abrir Scanner'),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _SeparationDetailScreen(orderId: order.id, ds: ds),
                      )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (order.separationTasks.every((t) => t.isCompleted))
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Finalizar'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                        onPressed: () async => await ds.completeSeparation(order.id),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SEPARATION DETAIL (Scanner Mode) ─────────────────────────────────────

class _SeparationDetailScreen extends StatefulWidget {
  final String orderId;
  final DataService ds;
  const _SeparationDetailScreen({required this.orderId, required this.ds});
  @override
  State<_SeparationDetailScreen> createState() => _SeparationDetailScreenState();
}

class _SeparationDetailScreenState extends State<_SeparationDetailScreen> {
  final _lotCtrl  = TextEditingController();
  String? _errorMsg;
  bool    _finalizing    = false;

  @override
  void dispose() {
    _lotCtrl.dispose();
    super.dispose();
  }

  // Próxima tarefa pendente
  SeparationTask? _currentTask(Order order) {
    final pending = order.separationTasks.where((t) => !t.isCompleted).toList();
    return pending.isNotEmpty ? pending.first : null;
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ds    = context.watch<DataService>();
    final order = ds.getOrder(widget.orderId);
    if (order == null) {
      return const Scaffold(body: Center(child: Text('Pedido não encontrado')));
    }

    final task           = _currentTask(order);
    final completedCount = order.separationTasks.where((t) => t.isCompleted).length;
    final totalCount     = order.separationTasks.length;
    final allDone        = totalCount > 0 && completedCount == totalCount;

    // Sem tarefas ainda — mostra loading/aviso
    if (totalCount == 0) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: Column(
          children: [
            GradientHeader(
              title: 'Separando: ${order.invoiceNumber}',
              subtitle: order.clientName,
              showBack: true,
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 56, color: AppTheme.warning),
                    SizedBox(height: 16),
                    Text('Sem tarefas de separação',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Não há lotes disponíveis em estoque para os itens deste pedido.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
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

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          GradientHeader(
            title: 'Separando: ${order.invoiceNumber}',
            subtitle: order.clientName,
            showBack: true,
          ),

          // ── Barra de progresso ─────────────────────────────────────────
          _ProgressBar(completed: completedCount, total: totalCount),

          // ── Corpo ──────────────────────────────────────────────────────
          Expanded(
            child: allDone
                ? _buildAllDone(context, order)
                : _buildScanner(context, order, task!, completedCount, totalCount),
          ),

          // ── Botão fixo no rodapé ───────────────────────────────────────
          _buildFooterButton(context, order, allDone, completedCount, totalCount),
        ],
      ),
    );
  }

  // ─── SCANNER (tarefas pendentes) ─────────────────────────────────────────
  Widget _buildScanner(BuildContext context, Order order, SeparationTask task,
      int completedCount, int totalCount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card da tarefa atual
          _TaskCard(task: task, completedCount: completedCount, totalCount: totalCount),
          const SizedBox(height: 16),

          // Campo único — bipe o lote
          _buildScanStep(
            title: 'Bipe o Lote',
            subtitle: 'Lote esperado: ${task.lotBarcode}',
            controller: _lotCtrl,
            hint: 'Ex: LOT-0001',
            onSubmit: () => _validateLot(order),
          ),

          // Mensagem de erro
          if (_errorMsg != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _errorMsg!),
          ],

          const SizedBox(height: 20),

          // Lista de todas as tarefas
          _TaskList(tasks: order.separationTasks, currentTask: task),
          const SizedBox(height: 80), // espaço para o botão fixo
        ],
      ),
    );
  }

  // ─── TELA DE TUDO CONCLUÍDO ───────────────────────────────────────────────
  Widget _buildAllDone(BuildContext context, Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(color: AppTheme.successLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, size: 72, color: AppTheme.success),
          ),
          const SizedBox(height: 20),
          const Text('Todos os itens bipados!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Revise abaixo e confirme a finalização.\nA baixa no estoque será realizada automaticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Resumo das tarefas concluídas
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
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(children: [
                    const Icon(Icons.task_alt, color: AppTheme.success, size: 16),
                    const SizedBox(width: 6),
                    Text('${order.separationTasks.length} tarefas concluídas',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                ),
                const Divider(height: 1),
                ...order.separationTasks.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        Text('${t.quantity} un. • ${t.addressCode} • ${t.lotBarcode}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    )),
                  ]),
                )),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─── BOTÃO FIXO NO RODAPÉ ─────────────────────────────────────────────────
  Widget _buildFooterButton(BuildContext context, Order order, bool allDone,
      int completedCount, int totalCount) {
    final pendingCount = totalCount - completedCount;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      child: allDone
          // ── Todos concluídos → botão verde de finalizar ──────────────
          ? SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _finalizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.verified, size: 20),
                label: Text(_finalizing
                    ? 'Finalizando...'
                    : 'Confirmar e Finalizar Separação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _finalizing ? null : () => _confirmFinalize(context, order),
              ),
            )
          // ── Itens pendentes → botão cinza bloqueado ──────────────────
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_outline, size: 20),
                label: Text(
                  pendingCount == 1
                      ? 'Falta 1 item para finalizar'
                      : 'Faltam $pendingCount itens para finalizar',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textHint,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Toque no botão bloqueado → explica o que falta
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      'Bipe todos os lotes antes de finalizar.\n'
                      '$pendingCount ${pendingCount == 1 ? "tarefa pendente" : "tarefas pendentes"}.',
                    ),
                    backgroundColor: AppTheme.warning,
                    duration: const Duration(seconds: 3),
                  ));
                },
              ),
            ),
    );
  }

  // ─── DIÁLOGO DE CONFIRMAÇÃO FINAL ────────────────────────────────────────
  Future<void> _confirmFinalize(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.verified, color: AppTheme.success),
          SizedBox(width: 10),
          Text('Confirmar Separação'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Todos os ${order.separationTasks.length} itens foram bipados.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.success, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A baixa no estoque será realizada e o pedido avançará para Faturamento.',
                    style: TextStyle(fontSize: 12, color: AppTheme.success),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      setState(() => _finalizing = true);
      await widget.ds.completeSeparation(order.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildScanStep({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String hint,
    required VoidCallback onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.qr_code_scanner, size: 15, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          BarcodeInputField(
            controller: controller,
            label: 'Código de Barras',
            hint: hint,
            onSubmit: onSubmit,
            autofocus: true,
          ),
        ],
      ),
    );
  }

  // Valida o lote bipado — com suporte a lote alternativo
  Future<void> _validateLot(Order order) async {
    final task  = _currentTask(order);
    if (task == null) return;
    final input = _lotCtrl.text.trim();
    if (input.isEmpty) return;

    // ── Lote correto ──────────────────────────────────────────────────────
    if (input == task.lotBarcode || input == task.lotId) {
      await _doCompleteTask(order, task);
      return;
    }

    // ── Verifica se é um lote alternativo válido (mesmo produto, com estoque) ──
    final altLot = widget.ds.allLots.where((l) =>
        (l.barcode == input || l.id == input) &&
        l.productId == widget.ds.allLots
            .where((x) => x.barcode == task.lotBarcode || x.id == task.lotId)
            .firstOrNull?.productId &&
        l.currentQuantity >= task.quantity &&
        l.isActive).firstOrNull;

    if (altLot != null) {
      // Lote alternativo do mesmo produto → pede confirmação
      final ok = await _showAltLotDialog(altLot, task);
      if (ok == true && context.mounted) {
        await _doCompleteTask(order, task, altBarcode: altLot.barcode, altLotId: altLot.id);
      }
      return;
    }

    // ── Código não encontrado ou lote de produto diferente ─────────────────
    setState(() =>
        _errorMsg = 'Lote incorreto!\nEsperado: ${task.lotBarcode}\nBipado: $input\n\n'
            'Verifique o código e tente novamente.');
  }

  // Exibe dialog de confirmação de lote alternativo
  Future<bool?> _showAltLotDialog(Lot altLot, SeparationTask task) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(child: Text('Lote diferente do indicado', style: TextStyle(fontSize: 15))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O lote bipado não é o recomendado pelo sistema (FIFO), '
              'mas é do mesmo produto e tem estoque suficiente.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            // Comparativo dos dois lotes
            _LotCompareRow(
              label: 'Recomendado',
              barcode: task.lotBarcode,
              address: task.addressCode,
              color: AppTheme.info,
              bgColor: AppTheme.infoLight,
            ),
            const SizedBox(height: 8),
            _LotCompareRow(
              label: 'Bipado',
              barcode: altLot.barcode,
              address: altLot.addressCode,
              color: AppTheme.warning,
              bgColor: AppTheme.warningLight,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.warning, size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Usar um lote fora da ordem FIFO pode gerar divergências no rastreio.',
                    style: TextStyle(fontSize: 11, color: AppTheme.warning),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usar mesmo assim'),
          ),
        ],
      ),
    );
  }

  // Executa a conclusão da tarefa e reseta o estado de UI
  Future<void> _doCompleteTask(Order order, SeparationTask task,
      {String? altBarcode, String? altLotId}) async {
    final productName = task.productName;
    final quantity    = task.quantity;
    final lotId       = altLotId ?? task.lotId;

    await widget.ds.completeTask(order.id, lotId);

    setState(() {
      _lotCtrl.clear();
      _errorMsg = null;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$productName — $quantity un. confirmados!',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor: altBarcode != null ? AppTheme.warning : AppTheme.success,
        duration: const Duration(seconds: 2),
      ));
    }
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int completed;
  final int total;
  const _ProgressBar({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? completed / total : 0.0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$completed/$total tarefas concluídas',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppTheme.divider,
            valueColor: AlwaysStoppedAnimation(
                completed == total ? AppTheme.success : AppTheme.primary),
            minHeight: 8,
          ),
        ),
      ]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final SeparationTask task;
  final int completedCount;
  final int totalCount;
  const _TaskCard(
      {required this.task,
      required this.completedCount,
      required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryLight]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                'TAREFA ${completedCount + 1} DE $totalCount',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(task.productName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${task.quantity} unidades a separar',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _infoBubble('Endereço', task.addressCode, Icons.location_on)),
            const SizedBox(width: 10),
            Expanded(child: _infoBubble('Lote', task.lotBarcode, Icons.qr_code)),
          ]),
        ],
      ),
    );
  }

  Widget _infoBubble(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, color: Colors.white, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 9)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );
}

class _TaskList extends StatelessWidget {
  final List<SeparationTask> tasks;
  final SeparationTask currentTask;
  const _TaskList({required this.tasks, required this.currentTask});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Todas as Tarefas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Text(
            '${tasks.where((t) => t.isCompleted).length}/${tasks.length}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 8),
        ...tasks.map((t) {
          final isCurrent  = t == currentTask;
          final bgColor    = t.isCompleted ? AppTheme.successLight
              : isCurrent ? AppTheme.infoLight
              : Colors.white;
          final borderColor = t.isCompleted
              ? AppTheme.success.withValues(alpha: 0.4)
              : isCurrent
                  ? AppTheme.info.withValues(alpha: 0.4)
                  : AppTheme.divider;
          final icon  = t.isCompleted ? Icons.check_circle
              : isCurrent ? Icons.play_circle
              : Icons.radio_button_unchecked;
          final color = t.isCompleted ? AppTheme.success
              : isCurrent ? AppTheme.info
              : AppTheme.textHint;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(
                    '${t.quantity} un. • ${t.addressCode} • ${t.lotBarcode}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              )),
              if (t.isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              if (isCurrent && !t.isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.info,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ATUAL',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
          );
        }),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: AppTheme.error, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _LotCompareRow extends StatelessWidget {
  final String label;
  final String barcode;
  final String address;
  final Color color;
  final Color bgColor;
  const _LotCompareRow({
    required this.label,
    required this.barcode,
    required this.address,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(barcode,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            Text('Endereço: $address',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ],
        )),
      ]),
    );
  }
}

// ─── SCANNER TAB ──────────────────────────────────────────────────────────

class _ScannerTab extends StatefulWidget {
  final DataService ds;
  const _ScannerTab({required this.ds});
  @override
  State<_ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<_ScannerTab> {
  final _ctrl = TextEditingController();
  String? _result;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scanner Universal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('Bipe qualquer código para consulta rápida', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          BarcodeInputField(
            controller: _ctrl,
            label: 'Código de Barras',
            hint: 'LOT-0001, ADDR-A0111...',
            onSubmit: _lookup,
            autofocus: true,
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isError ? AppTheme.errorLight : AppTheme.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (_isError ? AppTheme.error : AppTheme.success).withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_isError ? Icons.error : Icons.check_circle,
                    color: _isError ? AppTheme.error : AppTheme.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_result!, style: TextStyle(color: _isError ? AppTheme.error : AppTheme.textPrimary, fontSize: 13))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _lookup() {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;

    // Check if it's a lot
    final lot = widget.ds.getLotByBarcode(input);
    if (lot != null) {
      setState(() {
        _isError = false;
        _result = 'LOTE ENCONTRADO\nProduto: ${lot.productName}\nSKU: ${lot.productSku}\nEstoque: ${lot.currentQuantity} un.\nEndereço: ${lot.addressCode}\nNF: ${lot.invoiceNumber}';
      });
      _ctrl.clear();
      return;
    }

    // Check if it's an address
    final addr = widget.ds.getAddressByBarcode(input) ?? widget.ds.allAddresses.where((a) => a.code == input).firstOrNull;
    if (addr != null) {
      final lot2 = addr.currentLotId != null ? widget.ds.allLots.where((l) => l.id == addr.currentLotId).firstOrNull : null;
      setState(() {
        _isError = false;
        _result = 'ENDEREÇO: ${addr.displayName}\nStatus: ${addr.isOccupied ? "OCUPADO" : "LIVRE"}${lot2 != null ? "\nLote: ${lot2.barcode}\nProduto: ${lot2.productName}\nQtd: ${lot2.currentQuantity} un." : ""}';
      });
      _ctrl.clear();
      return;
    }

    setState(() {
      _isError = true;
      _result = 'Código "$input" não encontrado no sistema.\nVerifique se o lote ou endereço está cadastrado.';
    });
  }
}
