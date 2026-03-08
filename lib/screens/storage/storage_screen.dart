// lib/screens/storage/storage_screen.dart
// Dashboard de Gerenciamento de Armazenamento — Local + Firebase Ready

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});
  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  bool _running = false;
  CleanupReport? _lastReport;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _runCleanup({bool dryRun = false}) async {
    final confirmed = dryRun ? true : await _confirmDialog();
    if (!confirmed) return;
    if (!mounted) return;
    final ds = context.read<DataService>();
    setState(() => _running = true);
    try {
      final report = await ds.runCleanup(dryRun: dryRun);
      setState(() { _lastReport = report; _running = false; });
      if (!mounted) return;
      if (dryRun) {
        _showDryRunResult(report);
      } else {
        _showCleanupResult(report);
      }
    } catch (e) {
      setState(() => _running = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na limpeza: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<bool> _confirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.auto_fix_high, color: AppTheme.warning),
          SizedBox(width: 10),
          Text('Confirmar Limpeza'),
        ]),
        content: const Text(
          'A limpeza irá:\n\n'
          '• Arquivar pedidos finalizados/enviados +90 dias\n'
          '• Excluir arquivos com +365 dias\n'
          '• Compactar movimentações +60 dias\n'
          '• Remover notificações lidas +30 dias\n'
          '• Limpar lotes zerados sem atividade +30 dias\n\n'
          'Esta ação não pode ser desfeita. Deseja continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Executar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showDryRunResult(CleanupReport r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.visibility, color: AppTheme.info),
          SizedBox(width: 10),
          Text('Simulação (Dry Run)'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Se a limpeza fosse executada agora:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            if (!r.hasChanges)
              const _ResultRow(icon: Icons.check_circle_outline, color: AppTheme.success,
                  label: 'Nada a limpar — tudo em dia!')
            else ...[
              if (r.archivedOrders > 0)
                _ResultRow(icon: Icons.folder_open, color: AppTheme.info,
                    label: '${r.archivedOrders} pedido(s) seriam arquivados'),
              if (r.deletedArchives > 0)
                _ResultRow(icon: Icons.delete_outline, color: AppTheme.error,
                    label: '${r.deletedArchives} arquivo(s) seriam excluídos'),
              if (r.compactedMovements > 0)
                _ResultRow(icon: Icons.history, color: Colors.teal,
                    label: '${r.compactedMovements} movimentações compactadas'),
              if (r.deletedNotifications > 0)
                _ResultRow(icon: Icons.schedule, color: AppTheme.warning,
                    label: '${r.deletedNotifications} notificações removidas'),
              if (r.cleanedOrphanLots > 0)
                _ResultRow(icon: Icons.inventory_2, color: Colors.deepOrange,
                    label: '${r.cleanedOrphanLots} lote(s) órfão(s) limpos'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          if (r.hasChanges)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () { Navigator.pop(context); _runCleanup(dryRun: false); },
              child: const Text('Executar de Verdade', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  void _showCleanupResult(CleanupReport r) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.hasChanges
            ? '✅ Limpeza concluída! ${r.totalActions} item(ns) processados.'
            : '✅ Tudo limpo — nenhuma ação necessária.'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();

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
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Icon(Icons.storage_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gerenciar Armazenamento',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Compactar dados e limpeza automática',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── Conteúdo ──────────────────────────────────────────────────
          Expanded(child: _buildContent(ds)),
        ],
      ),
    );
  }

  Widget _buildContent(DataService ds) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Regras de retenção
        _RetentionRulesCard(),
        const SizedBox(height: 12),

        // Último relatório
        if (_lastReport != null) ...[
          _LastReportCard(report: _lastReport!),
          const SizedBox(height: 12),
        ],

        // Botões de ação
        _ActionButtons(
          running: _running,
          onDryRun: () => _runCleanup(dryRun: true),
          onCleanup: () => _runCleanup(dryRun: false),
        ),
        const SizedBox(height: 12),

        // Pedidos arquivados
        if (ds.archivedOrders.isNotEmpty)
          _ArchivedOrdersCard(ds: ds),
        const SizedBox(height: 80),
      ],
    );
  }

}


// ─────────────────────────────────────────────────────────────────────────────
// GAUGE DE USO (visual com arco)
// ─────────────────────────────────────────────────────────────────────────────
class _RetentionRulesCard extends StatelessWidget {
  const _RetentionRulesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.schedule, size: 18, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Regras de Retenção Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          _RuleRow(icon: Icons.folder_open, color: AppTheme.info,
              label: 'Pedidos finalizados/enviados', rule: 'Arquivar após 90 dias'),
          _RuleRow(icon: Icons.delete_outline, color: AppTheme.error,
              label: 'Pedidos arquivados', rule: 'Excluir após 365 dias'),
          _RuleRow(icon: Icons.history, color: Colors.teal,
              label: 'Movimentações de lote', rule: 'Compactar após 60 dias'),
          _RuleRow(icon: Icons.schedule, color: AppTheme.warning,
              label: 'Notificações lidas', rule: 'Remover após 30 dias'),
          _RuleRow(icon: Icons.inventory_2, color: Colors.deepOrange,
              label: 'Lotes zerados sem atividade', rule: 'Limpar após 30 dias'),
          _RuleRow(icon: Icons.notes, color: Colors.deepPurple,
              label: 'Eventos por pedido', rule: 'Máximo 20 eventos'),
        ]),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, rule;
  const _RuleRow({required this.icon, required this.color, required this.label, required this.rule});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      Text(rule, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _LastReportCard extends StatelessWidget {
  final CleanupReport report;
  const _LastReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.success.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.success),
            const SizedBox(width: 8),
            const Text('Último Relatório de Limpeza',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.success)),
            const Spacer(),
            Text(formatDateTime(report.executedAt),
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 10),
          if (!report.hasChanges)
            const Text('Nenhuma ação necessária.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
          else
            Wrap(
              spacing: 8, runSpacing: 6,
              children: [
                if (report.archivedOrders > 0) _ReportChip('${report.archivedOrders} arquivados', AppTheme.info),
                if (report.deletedArchives > 0) _ReportChip('${report.deletedArchives} excluídos', AppTheme.error),
                if (report.compactedMovements > 0) _ReportChip('${report.compactedMovements} movs compactadas', Colors.teal),
                if (report.deletedNotifications > 0) _ReportChip('${report.deletedNotifications} notifs removidas', AppTheme.warning),
                if (report.cleanedOrphanLots > 0) _ReportChip('${report.cleanedOrphanLots} lotes limpos', Colors.deepOrange),
              ],
            ),
        ]),
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ReportChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _ActionButtons extends StatelessWidget {
  final bool running;
  final VoidCallback onDryRun, onCleanup;
  const _ActionButtons({required this.running, required this.onDryRun, required this.onCleanup});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.tune, size: 18, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Ações de Limpeza', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: running ? null : onDryRun,
              icon: const Icon(Icons.visibility),
              label: const Text('Simular Limpeza (sem apagar nada)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.info,
                side: BorderSide(color: AppTheme.info.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: running ? null : onCleanup,
              icon: running
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high),
              label: Text(running ? 'Executando...' : 'Executar Limpeza Agora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Recomendado: simule antes de executar a limpeza real.',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
        ]),
      ),
    );
  }
}

class _ArchivedOrdersCard extends StatelessWidget {
  final DataService ds;
  const _ArchivedOrdersCard({required this.ds});

  @override
  Widget build(BuildContext context) {
    final archived = ds.archivedOrders.toList()
      ..sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.folder_open, size: 18, color: AppTheme.info),
            const SizedBox(width: 8),
            Text('Pedidos Arquivados (${archived.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          const Text('Finalizados/cancelados. Podem ser restaurados.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ...archived.take(10).map((order) => _ArchivedOrderTile(order: order, ds: ds)),
          if (archived.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('+ ${archived.length - 10} pedidos mais antigos...',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ),
        ]),
      ),
    );
  }
}

class _ArchivedOrderTile extends StatelessWidget {
  final Order order;
  final DataService ds;
  const _ArchivedOrderTile({required this.order, required this.ds});

  @override
  Widget build(BuildContext context) {
    final isExpired = DateTime.now().difference(order.updatedAt ?? order.createdAt).inDays >= 365;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired ? AppTheme.errorLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpired ? AppTheme.error.withValues(alpha: 0.3) : AppTheme.divider),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NF: ${order.invoiceNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${order.clientName} • ${order.status.label}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text(formatDate(order.updatedAt ?? order.createdAt),
                style: TextStyle(fontSize: 10, color: isExpired ? AppTheme.error : AppTheme.textHint)),
          ]),
        ),
        if (isExpired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(6)),
            child: const Text('Pronto p/ excluir',
                style: TextStyle(fontSize: 9, color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () async {
            await ds.restoreArchivedOrder(order.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Pedido NF ${order.invoiceNumber} restaurado.'),
                    backgroundColor: AppTheme.success),
              );
            }
          },
          child: const Text('Restaurar', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _ResultRow({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
    ]),
  );
}
