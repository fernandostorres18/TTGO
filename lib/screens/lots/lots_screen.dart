// lib/screens/lots/lots_screen.dart
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LotDetailSheet(lot: lot, ds: ds),
    );
  }
}

class _LotDetailSheet extends StatelessWidget {
  final Lot lot;
  final DataService ds;
  const _LotDetailSheet({required this.lot, required this.ds});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textHint, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(lot.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  // Botão Etiqueta
                  IconButton(
                    icon: const Icon(Icons.label_outline, color: AppTheme.primary),
                    tooltip: 'Imprimir Etiqueta',
                    onPressed: () => _showLabelScreen(context),
                  ),
                  if (ds.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      tooltip: 'Excluir lote',
                      onPressed: () => _confirmDeleteFromDetail(context),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Barcode
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                child: Column(
                  children: [
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: lot.barcode,
                      width: double.infinity,
                      height: 60,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(lot.barcode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.info, letterSpacing: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoCard([
                _row('Produto', lot.productName),
                _row('SKU', lot.productSku),
                _row('NF Entrada', lot.invoiceNumber),
                _row('Data Entrada', formatDate(lot.receivedAt)),
                _row('Qtd Recebida', '${lot.receivedQuantity} un.'),
                _row('Qtd Atual', '${lot.currentQuantity} un.', color: lot.currentQuantity > 0 ? AppTheme.primary : AppTheme.error),
                _row('Endereço', lot.addressCode, color: AppTheme.primary),
              ]),
              const SizedBox(height: 16),
              const Text('Movimentações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...lot.movements.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: m.type == 'entrada' ? AppTheme.successLight : AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(m.type == 'entrada' ? Icons.add_circle : Icons.remove_circle,
                      color: m.type == 'entrada' ? AppTheme.success : AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(formatDateTime(m.date), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    )),
                    Text('${m.type == 'saida' ? '-' : '+'}${m.quantity} un.',
                      style: TextStyle(fontWeight: FontWeight.bold,
                        color: m.type == 'entrada' ? AppTheme.success : AppTheme.error)),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showLabelScreen(BuildContext context) {
    // rootNavigator: true garante uso do Navigator raiz (necessário no web
    // quando chamado de dentro de um ModalBottomSheet)
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => _LotLabelScreen(lot: lot, ds: ds)),
    );
  }

  void _confirmDeleteFromDetail(BuildContext context) {
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
              Navigator.pop(context); // fechar dialog
              Navigator.pop(context); // fechar bottom sheet
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

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
    child: Column(children: rows),
  );

  Widget _row(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppTheme.textPrimary)),
      ],
    ),
  );
}

// ─── LOT LABEL SCREEN ───────────────────────────────────────────────────────

class _LotLabelScreen extends StatelessWidget {
  final Lot lot;
  final DataService ds;
  const _LotLabelScreen({required this.lot, required this.ds});

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
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conecte uma impressora Bluetooth para imprimir a etiqueta.'),
                  duration: Duration(seconds: 3),
                ),
              ),
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/icons/app_icon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.warehouse,
                                      color: AppTheme.primary,
                                      size: 24,
                                    ),
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
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Compartilhamento disponível na versão completa.')),
                        ),
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
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Conecte uma impressora Bluetooth para imprimir.'),
                            backgroundColor: AppTheme.primary,
                          ),
                        ),
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
