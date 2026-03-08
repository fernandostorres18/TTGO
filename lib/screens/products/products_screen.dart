// lib/screens/products/products_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    var products = ds.currentClientProducts;
    if (_search.isNotEmpty) {
      products = products.where((p) =>
        p.name.toLowerCase().contains(_search) ||
        p.sku.toLowerCase().contains(_search)).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          GradientHeader(
            title: 'Produtos',
            subtitle: 'Catálogo de produtos',
            showBack: true,
            trailing: ds.isAdmin || ds.isOperator
              ? IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _showForm(context, null),
                )
              : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar produto ou SKU...',
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
            child: products.isEmpty
              ? EmptyState(icon: Icons.category, title: 'Nenhum produto', subtitle: 'Cadastre produtos para seu cliente', actionLabel: 'Adicionar', onAction: () => _showForm(context, null))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    final stock = ds.getStockByProduct(p.id);
                    final isLow = stock <= p.minimumStock;
                    final client = ds.getClient(p.clientId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isLow ? AppTheme.errorLight : AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.inventory_2, color: isLow ? AppTheme.error : AppTheme.primary, size: 22),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SKU: ${p.sku} • ${p.weightKg}kg • ${p.orderSize.label}', style: const TextStyle(fontSize: 11)),
                            if (ds.isAdmin && client != null)
                              Text('Cliente: ${client.companyName}', style: const TextStyle(fontSize: 10, color: AppTheme.info)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$stock un.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isLow ? AppTheme.error : AppTheme.primary)),
                                Text('Mín: ${p.minimumStock}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              ],
                            ),
                            if (ds.isAdmin || ds.isOperator) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                tooltip: 'Excluir produto',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeleteProduct(context, p, ds),
                              ),
                            ],
                          ],
                        ),
                        onTap: ds.isAdmin || ds.isOperator ? () => _showForm(context, p) : null,
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product p, DataService ds) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.error),
            SizedBox(width: 10),
            Text('Excluir Produto'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja excluir o produto "${p.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'Atenção: não é possível excluir produtos com lotes ativos em estoque.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
              final ok = await ds.deleteProduct(p.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Produto "${p.name}" excluído com sucesso.'
                      : 'Não foi possível excluir: produto possui lotes ativos em estoque.'),
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

  void _showForm(BuildContext context, Product? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductForm(product: product, ds: context.read<DataService>()),
    );
  }
}

class _ProductForm extends StatefulWidget {
  final Product? product;
  final DataService ds;
  const _ProductForm({this.product, required this.ds});
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final _skuCtrl = TextEditingController(text: widget.product?.sku);
  late final _nameCtrl = TextEditingController(text: widget.product?.name);
  late final _eanCtrl = TextEditingController(text: widget.product?.ean);
  late final _nfeCodeCtrl = TextEditingController(text: widget.product?.nfeProductCode);
  late final _weightCtrl = TextEditingController(text: widget.product?.weightKg.toString());
  late final _hCtrl = TextEditingController(text: widget.product?.heightCm.toString());
  late final _wCtrl = TextEditingController(text: widget.product?.widthCm.toString());
  late final _lCtrl = TextEditingController(text: widget.product?.lengthCm.toString());
  late final _minCtrl = TextEditingController(text: widget.product?.minimumStock.toString() ?? '10');
  String? _clientId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _clientId = widget.product?.clientId ?? (widget.ds.isClient ? widget.ds.currentClientId : null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product == null ? 'Novo Produto' : 'Editar Produto',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (widget.ds.isAdmin)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Cliente *', prefixIcon: Icon(Icons.business, size: 18)),
                initialValue: _clientId,
                items: widget.ds.activeClients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.companyName))).toList(),
                onChanged: (v) => setState(() => _clientId = v),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_skuCtrl, 'SKU *', Icons.qr_code)),
              const SizedBox(width: 10),
              Expanded(child: _field(_nameCtrl, 'Nome *', Icons.label)),
            ]),
            const SizedBox(height: 10),
            // ── Identificação NF-e ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.receipt_long, size: 14, color: Colors.indigo),
                    SizedBox(width: 6),
                    Text('Identificação na NF-e',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                    'Preencha para cruzar automaticamente com XML de saída.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_eanCtrl, 'EAN / GTIN (cEAN)', Icons.barcode_reader)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_nfeCodeCtrl, 'Cód. Produto NF-e (cProd)', Icons.numbers)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('Dimensões e Peso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(_weightCtrl, 'Peso (kg)', Icons.scale)),
              const SizedBox(width: 6),
              Expanded(child: _field(_hCtrl, 'Alt (cm)', Icons.height)),
              const SizedBox(width: 6),
              Expanded(child: _field(_wCtrl, 'Larg (cm)', Icons.width_normal)),
              const SizedBox(width: 6),
              Expanded(child: _field(_lCtrl, 'Comp (cm)', Icons.straighten)),
            ]),
            const SizedBox(height: 10),
            _field(_minCtrl, 'Estoque Mínimo', Icons.warning_amber),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: Text(_loading ? 'Salvando...' : 'Salvar Produto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String l, IconData i) =>
    TextFormField(controller: c, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 18)), keyboardType: TextInputType.text);

  Future<void> _save() async {
    if (_clientId == null) return;
    setState(() => _loading = true);
    if (widget.product == null) {
      await widget.ds.addProduct(Product(
        id: widget.ds.newProductId(),
        clientId: _clientId!,
        sku: _skuCtrl.text, name: _nameCtrl.text,
        ean: _eanCtrl.text.trim(),
        nfeProductCode: _nfeCodeCtrl.text.trim(),
        weightKg: double.tryParse(_weightCtrl.text) ?? 0,
        heightCm: double.tryParse(_hCtrl.text) ?? 0,
        widthCm: double.tryParse(_wCtrl.text) ?? 0,
        lengthCm: double.tryParse(_lCtrl.text) ?? 0,
        minimumStock: int.tryParse(_minCtrl.text) ?? 0,
        createdAt: DateTime.now(),
      ));
    } else {
      widget.product!.sku = _skuCtrl.text; widget.product!.name = _nameCtrl.text;
      widget.product!.ean = _eanCtrl.text.trim();
      widget.product!.nfeProductCode = _nfeCodeCtrl.text.trim();
      widget.product!.weightKg = double.tryParse(_weightCtrl.text) ?? 0;
      widget.product!.heightCm = double.tryParse(_hCtrl.text) ?? 0;
      widget.product!.widthCm = double.tryParse(_wCtrl.text) ?? 0;
      widget.product!.lengthCm = double.tryParse(_lCtrl.text) ?? 0;
      widget.product!.minimumStock = int.tryParse(_minCtrl.text) ?? 0;
      await widget.ds.updateProduct(widget.product!);
    }
    if (mounted) Navigator.pop(context);
  }
}
