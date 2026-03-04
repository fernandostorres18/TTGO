// lib/screens/receiving/receiving_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/app_models.dart';

class ReceivingScreen extends StatefulWidget {
  const ReceivingScreen({super.key});
  @override
  State<ReceivingScreen> createState() => _ReceivingScreenState();
}

class _ReceivingScreenState extends State<ReceivingScreen>
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
                          )
                        else
                          const SizedBox(width: 12),
                        const Icon(Icons.move_to_inbox, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recebimento de Mercadorias',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('XML automático ou entrada manual',
                                  style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
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
                      Tab(text: 'Nova Entrada'),
                      Tab(text: 'Histórico'),
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
                _NewReceivingTab(ds: ds),
                _ReceivingHistoryTab(ds: ds),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── NEW RECEIVING TAB ──────────────────────────────────────────────────────

class _NewReceivingTab extends StatefulWidget {
  final DataService ds;
  const _NewReceivingTab({required this.ds});
  @override
  State<_NewReceivingTab> createState() => _NewReceivingTabState();
}

class _NewReceivingTabState extends State<_NewReceivingTab> {
  int _step = 0; // 0=info, 1=items, 2=addresses, 3=confirm
  bool _loading = false;

  String? _selectedClientId;
  final _nfCtrl = TextEditingController();

  // Lista de itens selecionados para entrada
  List<_ReceivingEntry> _entries = [];

  @override
  void dispose() {
    _nfCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _step = 0;
      _selectedClientId = null;
      _nfCtrl.clear();
      _entries = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 16),
          if (_step == 0) _buildStep0Info(),
          if (_step == 1) _buildStep1Items(),
          if (_step == 2) _buildStep2Addresses(),
          if (_step == 3) _buildStep3Confirm(),
        ],
      ),
    );
  }

  // ── Indicador de passos ────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    const steps = ['Dados NF', 'Produtos', 'Endereços', 'Confirmar'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isDone = i < _step;
        final isCurrent = i == _step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppTheme.primary
                        : isCurrent
                            ? AppTheme.primarySurface
                            : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isCurrent ? AppTheme.primary : AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      Icon(
                          isDone ? Icons.check_circle : Icons.circle,
                          size: 16,
                          color: isDone
                              ? Colors.white
                              : isCurrent
                                  ? AppTheme.primary
                                  : AppTheme.textHint),
                      const SizedBox(height: 2),
                      Text(steps[i],
                          style: TextStyle(
                              fontSize: 9,
                              color: isDone
                                  ? Colors.white
                                  : isCurrent
                                      ? AppTheme.primary
                                      : AppTheme.textHint,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ],
                  ),
                ),
              ),
              if (i < steps.length - 1)
                Container(
                    height: 2,
                    width: 6,
                    color: i < _step ? AppTheme.primary : AppTheme.divider),
            ],
          ),
        );
      }),
    );
  }

  // ── Passo 0: Dados da NF (único modo: manual) ────────────────────────────
  Widget _buildStep0Info() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Passo 1: Dados da Entrada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),

        // Seleção de cliente
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
              labelText: 'Cliente *',
              prefixIcon: Icon(Icons.business, size: 18)),
          value: _selectedClientId,
          items: widget.ds.activeClients
              .map((c) =>
                  DropdownMenuItem(value: c.id, child: Text(c.companyName)))
              .toList(),
          onChanged: (v) =>
              setState(() => _selectedClientId = v),
        ),
        const SizedBox(height: 12),

        // Número NF
        TextField(
          controller: _nfCtrl,
          decoration: const InputDecoration(
            labelText: 'Número da Nota Fiscal',
            hintText: 'Ex: NF-001234 (opcional)',
            prefixIcon: Icon(Icons.receipt, size: 18),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Avançar para Produtos'),
            onPressed: _selectedClientId != null ? _goToItems : null,
          ),
        ),
      ],
    );
  }

  void _goToItems() {
    setState(() {
      _entries = [];
      _step = 1;
    });
  }

  // ── Passo 1: Adicionar/remover produtos ──────────────────────────────────
  Widget _buildStep1Items() {
    final clientProducts =
        widget.ds.getProductsByClient(_selectedClientId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Passo 2: Produtos',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Selecione os produtos e quantidades',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text('Voltar'),
              onPressed: () => setState(() => _step = 0),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lista de itens já adicionados
        if (_entries.isNotEmpty) ...[
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
                      const Icon(Icons.inventory_2,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text('${_entries.length} produto(s) na entrada',
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: AppTheme.primarySurface,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.inventory_2,
                                  size: 16, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text('SKU: ${entry.sku}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            // Controle de quantidade
                            Row(
                              children: [
                                _qtyBtn(
                                  icon: Icons.remove,
                                  onTap: () {
                                    if (entry.quantity > 1) {
                                      setState(() => _entries[idx] =
                                          entry.withQty(entry.quantity - 1));
                                    }
                                  },
                                ),
                                Container(
                                  width: 48,
                                  alignment: Alignment.center,
                                  child: Text('${entry.quantity}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                ),
                                _qtyBtn(
                                  icon: Icons.add,
                                  onTap: () => setState(() => _entries[idx] =
                                      entry.withQty(entry.quantity + 1)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.error, size: 20),
                              onPressed: () =>
                                  setState(() => _entries.removeAt(idx)),
                              tooltip: 'Remover item',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
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
          const SizedBox(height: 14),
        ],

        // Botão / painel para adicionar produto
        _AddProductPanel(
            products: clientProducts,
            alreadyAdded: _entries.map((e) => e.productId).toList(),
            onAdd: (productId, productName, sku, qty) {
              setState(() {
                final existing =
                    _entries.indexWhere((e) => e.productId == productId);
                if (existing >= 0) {
                  _entries[existing] = _entries[existing]
                      .withQty(_entries[existing].quantity + qty);
                } else {
                  _entries.add(_ReceivingEntry(
                      productId: productId,
                      productName: productName,
                      sku: sku,
                      quantity: qty));
                }
              });
            },
          ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: Text('Avançar — ${_entries.length} produto(s)'),
            onPressed: _entries.isNotEmpty
                ? () => setState(() => _step = 2)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: AppTheme.primary),
      ),
    );
  }

  // ── Passo 2: Definir endereços ────────────────────────────────────────────
  Widget _buildStep2Addresses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Passo 3: Endereços de Armazenamento',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('Defina o endereço físico de cada lote',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text('Voltar'),
              onPressed: () => setState(() => _step = 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final freeAddrs = widget.ds.freeAddresses;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.inventory_2,
                            size: 16, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                                'SKU: ${e.sku}  •  ${e.quantity} unidades',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Endereço de armazenamento *',
                      prefixIcon: Icon(Icons.location_on,
                          size: 18, color: AppTheme.primary),
                    ),
                    value: e.addressId,
                    items: freeAddrs
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.displayName,
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _entries[i] = _entries[i].withAddress(
                            v, widget.ds.getAddress(v)?.code ?? '');
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Avançar para Confirmação'),
            onPressed: _entries.every((e) => e.addressId != null)
                ? () => setState(() => _step = 3)
                : null,
          ),
        ),
      ],
    );
  }

  // ── Passo 3: Confirmar ───────────────────────────────────────────────────
  Widget _buildStep3Confirm() {
    final client = widget.ds.getClient(_selectedClientId!);
    final nf = _nfCtrl.text.isNotEmpty
        ? _nfCtrl.text
        : 'NF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final totalUnits = _entries.fold(0, (s, e) => s + e.quantity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Passo 4: Confirmar Recebimento',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text('Voltar'),
              onPressed: () => setState(() => _step = 2),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Resumo
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                InfoRow(
                    label: 'Cliente',
                    value: client?.companyName ?? '',
                    icon: Icons.business),
                InfoRow(
                    label: 'Nota Fiscal', value: nf, icon: Icons.receipt),
                InfoRow(
                    label: 'Produtos',
                    value: '${_entries.length} SKU(s)',
                    icon: Icons.category),
                InfoRow(
                    label: 'Total de unidades',
                    value: '$totalUnits un.',
                    icon: Icons.numbers),
                InfoRow(
                    label: 'Modo de entrada',
                    value: 'Manual',
                    icon: Icons.input),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Lista resumida dos itens
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Itens a receber:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              ..._entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(e.productName,
                                style: const TextStyle(fontSize: 12))),
                        Text('${e.quantity} un.',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                fontSize: 12)),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 11, color: AppTheme.textSecondary),
                            Text(e.addressCode,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // O que será gerado
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(12)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, size: 15, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Será gerado automaticamente:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontSize: 12)),
              ]),
              SizedBox(height: 8),
              Text('• Código de barras único para cada lote',
                  style: TextStyle(fontSize: 12)),
              Text('• Registro no histórico de movimentações',
                  style: TextStyle(fontSize: 12)),
              Text('• Atualização do estoque em tempo real',
                  style: TextStyle(fontSize: 12)),
              Text('• Endereço físico vinculado ao lote',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_loading)
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 10),
                Text('Gerando lotes...', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: Text(
                  'Confirmar e Gerar ${_entries.length} Lote(s)'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _confirm,
            ),
          ),
      ],
    );
  }

  // _loadXml removido — recebimento usa apenas modo manual

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      final nf = _nfCtrl.text.isNotEmpty
          ? _nfCtrl.text
          : 'NF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      for (final entry in _entries) {
        final product = widget.ds.getProduct(entry.productId);
        if (product == null || entry.addressId == null) continue;
        await widget.ds.createLot(
          clientId: _selectedClientId!,
          product: product,
          quantity: entry.quantity,
          invoiceNumber: nf,
          addressId: entry.addressId!,
          addressCode: entry.addressCode,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_entries.length} lote(s) gerado(s) com sucesso!'),
          backgroundColor: AppTheme.success,
        ));
        _reset();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Mutable entry ────────────────────────────────────────────────────────────

class _ReceivingEntry {
  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final String? addressId;
  final String addressCode;

  const _ReceivingEntry({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    this.addressId,
    this.addressCode = '',
  });

  _ReceivingEntry withQty(int qty) => _ReceivingEntry(
      productId: productId,
      productName: productName,
      sku: sku,
      quantity: qty,
      addressId: addressId,
      addressCode: addressCode);

  _ReceivingEntry withAddress(String id, String code) => _ReceivingEntry(
      productId: productId,
      productName: productName,
      sku: sku,
      quantity: quantity,
      addressId: id,
      addressCode: code);
}

// ── Painel de adicionar produto ──────────────────────────────────────────────

class _AddProductPanel extends StatefulWidget {
  final List<Product> products;
  final List<String> alreadyAdded;
  final void Function(
          String productId, String productName, String sku, int qty)
      onAdd;

  const _AddProductPanel({
    required this.products,
    required this.alreadyAdded,
    required this.onAdd,
  });

  @override
  State<_AddProductPanel> createState() => _AddProductPanelState();
}

class _AddProductPanelState extends State<_AddProductPanel> {
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.warningLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4))),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  'Nenhum produto cadastrado para este cliente.\nCadastre produtos primeiro em "Produtos".',
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
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_box, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Adicionar produto',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdown de produto
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Produto *',
              prefixIcon: Icon(Icons.inventory_2, size: 18),
            ),
            value: _selectedProductId,
            hint: const Text('Selecione um produto'),
            items: widget.products.map((p) {
              final alreadyIn =
                  widget.alreadyAdded.contains(p.id);
              return DropdownMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.name,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: alreadyIn
                                      ? AppTheme.textSecondary
                                      : AppTheme.textPrimary)),
                          Text('SKU: ${p.sku}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (alreadyIn)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.check_circle,
                            size: 14, color: AppTheme.success),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedProductId = v),
          ),
          const SizedBox(height: 12),

          // Campo de quantidade
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Quantidade *',
                    prefixIcon: Icon(Icons.numbers, size: 18),
                    suffixText: 'un.',
                  ),
                  onChanged: (v) =>
                      setState(() => _qty = int.tryParse(v) ?? 1),
                ),
              ),
              const SizedBox(width: 10),
              // Botões + / -
              Column(
                children: [
                  _qtyBtn(Icons.add, () {
                    setState(() {
                      _qty++;
                      _qtyCtrl.text = '$_qty';
                    });
                  }),
                  const SizedBox(height: 6),
                  _qtyBtn(Icons.remove, () {
                    if (_qty > 1) {
                      setState(() {
                        _qty--;
                        _qtyCtrl.text = '$_qty';
                      });
                    }
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
              label: Text(_selectedProductId != null &&
                      widget.alreadyAdded.contains(_selectedProductId)
                  ? 'Atualizar quantidade'
                  : 'Adicionar à entrada'),
              onPressed: _selectedProductId != null && _qty > 0
                  ? _addProduct
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.info,
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: AppTheme.primary),
      ),
    );
  }

  void _addProduct() {
    final product = widget.products
        .firstWhere((p) => p.id == _selectedProductId);
    widget.onAdd(product.id, product.name, product.sku, _qty);
    // Reset
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

// ─── HISTORY TAB ─────────────────────────────────────────────────────────────

class _ReceivingHistoryTab extends StatelessWidget {
  final DataService ds;
  const _ReceivingHistoryTab({required this.ds});

  @override
  Widget build(BuildContext context) {
    final lots = List.of(ds.allLots)
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    if (lots.isEmpty) {
      return const EmptyState(
          icon: Icons.history, title: 'Nenhum recebimento ainda');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lots.length,
      itemBuilder: (context, i) {
        final lot = lots[i];
        final client = ds.getClient(lot.clientId);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2,
                  color: AppTheme.primary, size: 20),
            ),
            title: Text(lot.productName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NF: ${lot.invoiceNumber}  •  ${lot.addressCode}',
                    style: const TextStyle(fontSize: 11)),
                if (client != null)
                  Text(client.companyName,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.info)),
              ],
            ),
            isThreeLine: client != null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${lot.receivedQuantity} un.',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
                Text(formatDate(lot.receivedAt),
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
                StatusBadge(
                    label: lot.barcode,
                    color: AppTheme.info.withValues(alpha: 0.8)),
              ],
            ),
          ),
        );
      },
    );
  }
}
