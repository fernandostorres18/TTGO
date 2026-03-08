// lib/screens/lots/lots_screen.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class LotsScreen extends StatefulWidget {
  const LotsScreen({super.key});
  @override
  State<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends State<LotsScreen> {
  String _search = '';
  String? _filterClient;

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    var lots = ds.currentClientLots;

    // Filter
    if (_search.isNotEmpty) {
      lots = lots.where((l) =>
        l.barcode.toLowerCase().contains(_search) ||
        l.productName.toLowerCase().contains(_search) ||
        l.productSku.toLowerCase().contains(_search) ||
        l.invoiceNumber.toLowerCase().contains(_search)
      ).toList();
    }
    if (_filterClient != null && ds.isAdmin) {
      lots = lots.where((l) => l.clientId == _filterClient).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Row(
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
                        const Icon(Icons.inventory_2, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Controle de Lotes', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('Rastreabilidade por lote', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text('${lots.length} lotes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar lote, produto ou NF...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (v) => setState(() => _search = v.toLowerCase()),
                          ),
                        ),
                        if (ds.isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: PopupMenuButton<String?>(
                              icon: const Icon(Icons.filter_list, color: AppTheme.primary),
                              onSelected: (v) => setState(() => _filterClient = v),
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: null, child: Text('Todos')),
                                ...ds.activeClients.map((c) => PopupMenuItem(value: c.id, child: Text(c.companyName))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: lots.isEmpty
              ? const EmptyState(icon: Icons.inventory_2, title: 'Nenhum lote encontrado', subtitle: 'Os lotes aparecem após o recebimento de mercadorias')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: lots.length,
                  itemBuilder: (context, i) => _LotCard(lot: lots[i], ds: ds),
                ),
          ),
        ],
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  final Lot lot;
  final DataService ds;
  const _LotCard({required this.lot, required this.ds});

  @override
  Widget build(BuildContext context) {
    final product = ds.getProduct(lot.productId);
    final isLow = product != null && lot.currentQuantity <= product.minimumStock;
    final pct = lot.receivedQuantity > 0 ? lot.currentQuantity / lot.receivedQuantity : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
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
                      color: isLow ? AppTheme.errorLight : AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2, size: 20, color: isLow ? AppTheme.error : AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lot.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('SKU: ${lot.productSku}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label: lot.barcode,
                            color: AppTheme.info,
                            bgColor: AppTheme.infoLight,
                          ),
                          if (ds.isAdmin) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _confirmDeleteLot(context),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isLow) const SizedBox(height: 4),
                      if (isLow) const StatusBadge(label: 'ESTOQUE BAIXO', color: AppTheme.error),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stock bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estoque: ${lot.currentQuantity}/${lot.receivedQuantity} un.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: isLow ? AppTheme.error : AppTheme.textPrimary)),
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 11, color: isLow ? AppTheme.error : AppTheme.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.divider,
                            valueColor: AlwaysStoppedAnimation(isLow ? AppTheme.error : AppTheme.primary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(lot.addressCode, style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  const Icon(Icons.receipt_outlined, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('NF: ${lot.invoiceNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text(formatDate(lot.receivedAt), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
              if (ds.isAdmin) ...[
                const SizedBox(height: 6),
                Text('Cliente: ${ds.getClient(lot.clientId)?.companyName ?? lot.clientId}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteLot(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.error),
            SizedBox(width: 10),
            Text('Excluir Lote'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja excluir o lote "${lot.barcode}" (${lot.productName})?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Atenção: não é possível excluir lotes em separação ativa. '
                'O endereço físico será liberado automaticamente.',
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ds.deleteLot(lot.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Lote "${lot.barcode}" excluído com sucesso.'
                      : 'Não foi possível excluir: lote está em separação ativa.'),
                  backgroundColor: ok ? AppTheme.success : AppTheme.error,
                ));
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LotDetailScreen(lotId: lot.id)),
    );
  }
}

class LotDetailScreen extends StatefulWidget {
  final String lotId;
  const LotDetailScreen({super.key, required this.lotId});
  @override
  State<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends State<LotDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final lot = ds.allLots.firstWhere(
      (l) => l.id == widget.lotId,
      orElse: () => ds.allLots.first,
    );
    return _LotDetailBody(lot: lot, ds: ds);
  }
}

class _LotDetailBody extends StatelessWidget {
  final Lot lot;
  final DataService ds;
  const _LotDetailBody({required this.lot, required this.ds});

  @override
  Widget build(BuildContext context) {
    final pct = lot.receivedQuantity > 0 ? lot.currentQuantity / lot.receivedQuantity : 0.0;
    final isLow = lot.currentQuantity == 0;

    // Agrupa movimentações por tipo para cores
    Color movColor(String type) {
      if (type == 'entrada') return AppTheme.success;
      if (type == 'ajuste_entrada') return Colors.teal;
      if (type == 'ajuste_saida') return Colors.orange;
      return AppTheme.error; // saida
    }
    IconData movIcon(String type) {
      if (type == 'entrada') return Icons.add_circle;
      if (type == 'ajuste_entrada') return Icons.tune;
      if (type == 'ajuste_saida') return Icons.tune;
      return Icons.remove_circle;
    }
    String movLabel(String type) {
      switch (type) {
        case 'entrada': return 'ENTRADA';
        case 'saida': return 'SAÍDA';
        case 'ajuste_entrada': return 'AJUSTE +';
        case 'ajuste_saida': return 'AJUSTE −';
        default: return type.toUpperCase();
      }
    }
    bool isPositive(String type) => type == 'entrada' || type == 'ajuste_entrada';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Icon(Icons.inventory_2, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lot.productName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                    Text('SKU: ${lot.productSku} • ${lot.barcode}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ])),
                  if (ds.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      tooltip: 'Ajustar quantidade',
                      onPressed: () => _showAdjustQuantity(context),
                    ),
                  if (ds.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.move_down, color: Colors.white),
                      tooltip: 'Mover para outro endereço',
                      onPressed: () => _showMoveAddress(context),
                    ),
                  IconButton(
                    icon: const Icon(Icons.label_outline, color: Colors.white),
                    tooltip: 'Etiqueta',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LotLabelScreen(lot: lot, ds: ds))),
                  ),
                  if (ds.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white70),
                      tooltip: 'Excluir lote',
                      onPressed: () => _confirmDelete(context),
                    ),
                ]),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Estoque atual ─────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.inventory_2, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text('Estoque Atual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${lot.currentQuantity}',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: isLow ? AppTheme.error : AppTheme.primary,
                                )),
                            const SizedBox(width: 4),
                            Text('/ ${lot.receivedQuantity} un.',
                                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: AppTheme.divider,
                              valueColor: AlwaysStoppedAnimation(
                                isLow ? AppTheme.error : pct < 0.3 ? AppTheme.warning : AppTheme.success,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${(pct * 100).toStringAsFixed(0)}% restante',
                              style: TextStyle(
                                fontSize: 11,
                                color: isLow ? AppTheme.error : AppTheme.textSecondary,
                              )),
                        ])),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: (isLow ? AppTheme.error : AppTheme.success).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isLow ? AppTheme.error : AppTheme.success).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isLow ? 'ZERADO' : 'ATIVO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isLow ? AppTheme.error : AppTheme.success,
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Código de barras ─────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: lot.barcode,
                        width: double.infinity,
                        height: 60,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(lot.barcode,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                              color: AppTheme.info, letterSpacing: 2)),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Informações do lote ───────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text('Informações do Lote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const Divider(height: 20),
                      _infoRow('Produto', lot.productName),
                      _infoRow('SKU', lot.productSku),
                      _infoRow('NF de Entrada', lot.invoiceNumber),
                      _infoRow('Data de Entrada', formatDate(lot.receivedAt)),
                      _infoRow('Qtd Recebida', '${lot.receivedQuantity} un.'),
                      _infoRow('Qtd Atual', '${lot.currentQuantity} un.',
                          valueColor: lot.currentQuantity > 0 ? AppTheme.primary : AppTheme.error),
                      _infoRow('Endereço no Armazém', lot.addressCode,
                          valueColor: AppTheme.primary),
                      if (ds.isAdmin)
                        _infoRow('Cliente', ds.getClient(lot.clientId)?.companyName ?? lot.clientId),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Histórico de Movimentações ────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Row(children: [
                          Icon(Icons.history, size: 16, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Histórico de Movimentações',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${lot.movements.length} registro${lot.movements.length != 1 ? "s" : ""}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      if (lot.movements.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('Nenhuma movimentação registrada',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ),
                        )
                      else
                        // Timeline de movimentações (mais recente primeiro)
                        ...lot.movements.reversed.toList().asMap().entries.map((entry) {
                          final idx = entry.key;
                          final m = entry.value;
                          final color = movColor(m.type);
                          final isPos = isPositive(m.type);
                          final isLast = idx == lot.movements.length - 1;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline line + dot
                                Column(children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                                    ),
                                    child: Icon(movIcon(m.type), size: 15, color: color),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 24,
                                      color: AppTheme.divider,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                    ),
                                ]),
                                const SizedBox(width: 12),
                                // Content
                                Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: color.withValues(alpha: 0.2)),
                                    ),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Badge tipo
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(movLabel(m.type),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: color,
                                                )),
                                          ),
                                          // Quantidade
                                          Text(
                                            '${isPos ? "+" : "−"}${m.quantity} un.',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(m.description,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Text(formatDateTime(m.date),
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ]),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMoveAddress(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MoveAddressSheet(lot: lot, ds: ds),
    );
  }

  void _showAdjustQuantity(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AdjustQuantitySheet(lot: lot, ds: ds),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: AppTheme.error),
          SizedBox(width: 10),
          Text('Excluir Lote'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja excluir o lote "${lot.barcode}" (${lot.productName})?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'O endereço físico será liberado automaticamente.',
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ds.deleteLot(lot.id);
              if (context.mounted) {
                Navigator.pop(context); // voltar para lista
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Lote "${lot.barcode}" excluído com sucesso.'
                      : 'Não foi possível excluir: lote está em separação ativa.'),
                  backgroundColor: ok ? AppTheme.success : AppTheme.error,
                ));
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary,
              )),
        ),
      ],
    ),
  );
}

class _AdjustQuantitySheet extends StatefulWidget {
  final Lot lot;
  final DataService ds;
  const _AdjustQuantitySheet({required this.lot, required this.ds});
  @override
  State<_AdjustQuantitySheet> createState() => _AdjustQuantitySheetState();
}

class _AdjustQuantitySheetState extends State<_AdjustQuantitySheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  String _operation = 'add'; // 'add' ou 'remove'
  bool _loading = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Ajustar Quantidade',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),

            // Info do lote
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 18, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.lot.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${widget.lot.barcode} • Endereço: ${widget.lot.addressCode}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('${widget.lot.currentQuantity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.indigo)),
                      const Text('atual',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            // Operação
            Row(
              children: [
                Expanded(
                  child: _OpChip(
                    label: '+ Adicionar',
                    icon: Icons.add_circle_outline,
                    selected: _operation == 'add',
                    color: AppTheme.success,
                    onTap: () => setState(() => _operation = 'add'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OpChip(
                    label: '− Retirar',
                    icon: Icons.remove_circle_outline,
                    selected: _operation == 'remove',
                    color: AppTheme.error,
                    onTap: () => setState(() => _operation = 'remove'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quantidade
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantidade',
                prefixIcon: Icon(
                  _operation == 'add'
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: _operation == 'add'
                      ? AppTheme.success
                      : AppTheme.error,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Motivo
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo do ajuste *',
                hintText: 'Ex: Contagem física, avaria, devolução...',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 6),

            // Preview do resultado
            Builder(builder: (_) {
              final qty = int.tryParse(_qtyCtrl.text) ?? 0;
              final delta = _operation == 'add' ? qty : -qty;
              final result = widget.lot.currentQuantity + delta;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (result < 0 ? AppTheme.error : AppTheme.success)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quantidade após ajuste:',
                        style: TextStyle(fontSize: 12)),
                    Text(
                      result < 0 ? 'Inválido' : '$result unidades',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: result < 0
                              ? AppTheme.error
                              : AppTheme.success),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

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
                    : const Icon(Icons.check, color: Colors.white),
                label: Text(
                  _loading ? 'Salvando...' : 'Confirmar Ajuste',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _operation == 'add'
                      ? AppTheme.success
                      : AppTheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida')));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo do ajuste')));
      return;
    }
    setState(() => _loading = true);
    final delta = _operation == 'add' ? qty : -qty;
    final error = await widget.ds.adjustLotQuantity(
        widget.lot.id, delta, _reasonCtrl.text.trim());

    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context); // fecha sheet de ajuste
      Navigator.pop(context); // fecha sheet de detalhe
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ??
            'Ajuste realizado! ${_operation == 'add' ? '+$qty' : '-$qty'} unidades no lote ${widget.lot.barcode}.'),
        backgroundColor: error != null ? AppTheme.error : AppTheme.success,
      ));
    }
  }
}

class _OpChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _OpChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── MOVE ADDRESS SHEET ─────────────────────────────────────────────────────

class _MoveAddressSheet extends StatefulWidget {
  final Lot lot;
  final DataService ds;
  const _MoveAddressSheet({required this.lot, required this.ds});

  @override
  State<_MoveAddressSheet> createState() => _MoveAddressSheetState();
}

class _MoveAddressSheetState extends State<_MoveAddressSheet> {
  String? _selectedAddressId;
  bool _loading = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final ds = widget.ds;
    final lot = widget.lot;

    // Endereços livres (ou o próprio do lote para exibição)
    final available = ds.allAddresses
        .where((a) =>
            !a.isOccupied ||
            a.id == lot.addressId ||
            a.currentLotId == lot.id)
        .where((a) => _search.isEmpty ||
            a.code.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text('Mover para outro Endereço',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),

          // Endereço atual
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.location_on, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('Endereço atual: ',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text(lot.addressCode,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary)),
            ]),
          ),
          const SizedBox(height: 12),

          // Campo de busca
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar endereço...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),

          // Lista de endereços livres
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Nenhum endereço livre disponível',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: ListView.builder(
                itemCount: available.length,
                itemBuilder: (ctx, i) {
                  final addr = available[i];
                  final isCurrent = addr.id == lot.addressId;
                  final isSelected = _selectedAddressId == addr.id;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: AppTheme.primarySurface,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isCurrent
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : isSelected
                              ? AppTheme.primary
                              : Colors.grey[200],
                      child: Icon(
                        isCurrent ? Icons.check : Icons.location_on_outlined,
                        size: 14,
                        color: (isCurrent || isSelected) ? AppTheme.primary : Colors.grey[600],
                      ),
                    ),
                    title: Text(addr.code,
                        style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? AppTheme.textSecondary : null)),
                    subtitle: isCurrent ? const Text('Endereço atual', style: TextStyle(fontSize: 11)) : null,
                    trailing: isCurrent
                        ? const Chip(
                            label: Text('Atual', style: TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    onTap: isCurrent
                        ? null
                        : () => setState(() => _selectedAddressId = addr.id),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Botões
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.move_down, size: 18),
                label: Text(_loading ? 'Movendo...' : 'Mover'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAddressId != null
                      ? AppTheme.primary
                      : Colors.grey[400],
                ),
                onPressed: _selectedAddressId == null || _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        final err = await ds.moveLot(lot.id, _selectedAddressId!);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(err == null
                              ? 'Lote movido para o novo endereço com sucesso!'
                              : 'Erro: $err'),
                          backgroundColor: err == null ? AppTheme.success : AppTheme.error,
                          duration: const Duration(seconds: 3),
                        ));
                      },
              ),
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── LOT LABEL SCREEN ───────────────────────────────────────────────────────

class _LotLabelScreen extends StatelessWidget {
  final Lot lot;
  final DataService ds;
  const _LotLabelScreen({required this.lot, required this.ds});

  void _printLabel(BuildContext context) {
    final client = ds.getClient(lot.clientId);
    final clientName = client?.companyName ?? '';
    final now = DateTime.now();
    final dataStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Impressora térmica 58 mm — retrato, sem cores de fundo
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Etiqueta ${lot.barcode}</title>
<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.11.6/dist/JsBarcode.all.min.js"></script>
<style>
  @page {
    size: 58mm auto;
    margin: 0mm 2mm;
  }
  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }
  html, body {
    width: 54mm;
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    background: #fff;
  }
  .wrap {
    width: 54mm;
    padding: 1mm 0;
    display: flex;
    flex-direction: column;
    gap: 1.2mm;
  }

  /* --- Cabeçalho: borda simples, sem fundo --- */
  .hdr {
    text-align: center;
    border: 0.6mm solid #000;
    padding: 1.5mm 0;
    font-size: 11pt;
    font-weight: 900;
    letter-spacing: 0.5pt;
  }

  /* --- Nome do produto --- */
  .produto {
    text-align: center;
    font-size: 11pt;
    font-weight: bold;
    word-break: break-word;
    padding: 1mm 0;
    overflow-wrap: break-word;
  }

  .hr { border-top: 0.5mm solid #000; }

  /* --- Código de barras --- */
  .bc-wrap {
    text-align: center;
    padding: 0;
    overflow: hidden;
  }
  .bc-wrap svg {
    display: block;
    width: 54mm !important;
    height: 14mm !important;
  }
  .bc-code {
    font-family: 'Courier New', monospace;
    font-size: 8.5pt;
    font-weight: bold;
    text-align: center;
    letter-spacing: 1pt;
    margin-top: 0.5mm;
  }

  /* --- Bloco Quantidade --- */
  .qtd-box {
    border: 0.5mm solid #000;
    text-align: center;
    padding: 1mm 0;
  }
  .qtd-lbl {
    font-size: 7pt;
    font-weight: bold;
    text-transform: uppercase;
  }
  .qtd-val {
    font-size: 22pt;
    font-weight: 900;
    line-height: 1.1;
  }

  /* --- Linhas de dados --- */
  .row {
    display: flex;
    gap: 1mm;
    padding: 0.5mm 0;
    border-bottom: 0.2mm solid #ccc;
  }
  .lbl {
    font-size: 7pt;
    font-weight: 900;
    white-space: nowrap;
    min-width: 21mm;
    max-width: 21mm;
    text-transform: uppercase;
  }
  .val {
    font-size: 8.5pt;
    font-weight: bold;
    word-break: break-word;
    overflow-wrap: break-word;
    flex: 1;
    max-width: 31mm;
  }

  /* --- Rodapé --- */
  .ftr {
    text-align: center;
    font-size: 7pt;
    border-top: 0.5mm solid #000;
    padding-top: 1mm;
  }

  @media print {
    html, body { margin: 0; }
  }
</style>
</head>
<body>
<div class="wrap">

  <div class="hdr">ETIQUETA DE LOTE</div>

  <div class="produto">${lot.productName}</div>

  <div class="hr"></div>

  <div class="bc-wrap">
    <svg id="barcode"></svg>
    <div class="bc-code">${lot.barcode}</div>
  </div>

  <div class="hr"></div>

  <div class="qtd-box">
    <div class="qtd-lbl">QTD EM ESTOQUE</div>
    <div class="qtd-val">${lot.currentQuantity} un.</div>
  </div>

  <div class="hr"></div>

  <div class="row"><span class="lbl">SKU</span><span class="val">${lot.productSku}</span></div>
  <div class="row"><span class="lbl">ENDERECO</span><span class="val">${lot.addressCode}</span></div>
  <div class="row"><span class="lbl">NF ENTRADA</span><span class="val">${lot.invoiceNumber}</span></div>
  ${clientName.isNotEmpty ? '<div class="row"><span class="lbl">CLIENTE</span><span class="val">$clientName</span></div>' : ''}
  <div class="row"><span class="lbl">QTD RECEBIDA</span><span class="val">${lot.receivedQuantity} un.</span></div>
  <div class="row"><span class="lbl">DATA ENTRADA</span><span class="val">$dataStr</span></div>

  <div class="ftr">Fulfillment Master | $dataStr</div>

</div>
<script>
  JsBarcode("#barcode", "${lot.barcode}", {
    format: "CODE128",
    width: 1.6,
    height: 55,
    displayValue: false,
    margin: 0,
    background: "#ffffff",
    lineColor: "#000000"
  });
  setTimeout(function() { window.print(); }, 800);
</script>
</body>
</html>''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future.delayed(
        const Duration(seconds: 3), () => html.Url.revokeObjectUrl(url));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Etiqueta aberta em nova aba. Selecione sua impressora 58mm e clique em Imprimir.'),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = ds.getClient(lot.clientId);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Etiqueta do Lote',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Visualização para impressão',
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.print, color: Colors.white, size: 20),
              tooltip: 'Imprimir',
              onPressed: () => _printLabel(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // ── Etiqueta ────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ── Cabeçalho colorido ─────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDark],
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              // Logo do app
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Image.asset(
                                  'assets/images/ttgo_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.local_shipping,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ETIQUETA DE LOTE',
                                        style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 9,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.bold)),
                                    const Text('Fulfillment Master',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('DATA ENTRADA',
                                      style: TextStyle(color: Colors.white60, fontSize: 9)),
                                  Text(formatDate(lot.receivedAt),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Corpo ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // Nome do produto
                              Text(
                                lot.productName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1A2E),
                                    height: 1.2),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('SKU: ${lot.productSku}',
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 16),

                              // Grid de informações
                              _LabelInfoGrid(items: [
                                _LabelInfoItem(icon: Icons.business,       label: 'Cliente',       value: client?.companyName ?? lot.clientId),
                                _LabelInfoItem(icon: Icons.receipt,        label: 'NF Entrada',    value: lot.invoiceNumber),
                                _LabelInfoItem(icon: Icons.location_on,    label: 'Endereço',      value: lot.addressCode),
                                _LabelInfoItem(icon: Icons.inventory,      label: 'Qtd Recebida',  value: '${lot.receivedQuantity} un.'),
                                _LabelInfoItem(icon: Icons.store,          label: 'Qtd Atual',     value: '${lot.currentQuantity} un.'),
                                _LabelInfoItem(icon: Icons.calendar_today, label: 'Entrada',       value: formatDate(lot.receivedAt)),
                              ]),

                              const SizedBox(height: 20),

                              // Divisor pontilhado
                              Row(
                                children: List.generate(
                                  40,
                                  (i) => Expanded(
                                    child: Container(
                                      height: 1,
                                      color: i % 2 == 0 ? AppTheme.divider : Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Código de barras ──────────────────────
                              // O barcode exibido é EXATAMENTE lot.barcode,
                              // o mesmo valor usado pelo scanner para validar.
                              Center(
                                child: Column(
                                  children: [
                                    const Text('CÓDIGO DO LOTE',
                                        style: TextStyle(
                                            fontSize: 10,
                                            letterSpacing: 2,
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: BarcodeWidget(
                                        barcode: Barcode.code128(),
                                        data: lot.barcode,
                                        height: 80,
                                        drawText: false,
                                        color: const Color(0xFF1A1A2E),
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      lot.barcode,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                        color: Color(0xFF1A1A2E),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Rodapé da etiqueta
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.verified, size: 14, color: AppTheme.success),
                                      const SizedBox(width: 4),
                                      const Text('RASTREADO • FIFO',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.success,
                                              letterSpacing: 1)),
                                    ]),
                                    Text(
                                      '#${lot.id.length >= 8 ? lot.id.substring(0, 8).toUpperCase() : lot.id.toUpperCase()}',
                                      style: const TextStyle(
                                          fontSize: 10, color: AppTheme.textHint),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Botões de ação ──────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Compartilhar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _printLabel(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Imprimir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _printLabel(context),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelInfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _LabelInfoItem({required this.icon, required this.label, required this.value});
}

class _LabelInfoGrid extends StatelessWidget {
  final List<_LabelInfoItem> items;
  const _LabelInfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(item.icon, size: 11, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text(item.label,
                  style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 2),
            Text(item.value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      )).toList(),
    );
  }
}
