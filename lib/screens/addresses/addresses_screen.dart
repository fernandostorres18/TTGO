// lib/screens/addresses/addresses_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String? _filterStreet;

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
    final streets = ds.allAddresses.map((a) => a.street).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          GradientHeader(
            title: 'Endereços do Armazém',
            subtitle: '${ds.allAddresses.length} posições cadastradas',
            showBack: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => _showForm(context),
              ),
            ],
          ),
          // Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Todos', null, _filterStreet),
                  ...streets.map((s) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _filterChip('Rua $s', s, _filterStreet),
                  )),
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppTheme.primary,
              indicatorColor: AppTheme.primary,
              tabs: [
                Tab(text: 'Livres (${ds.freeAddresses.length})'),
                Tab(text: 'Ocupados (${ds.allAddresses.where((a) => a.isOccupied).length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _AddressList(addresses: _filter(ds.freeAddresses), ds: ds, showLot: false),
                _AddressList(addresses: _filter(ds.allAddresses.where((a) => a.isOccupied).toList()), ds: ds, showLot: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<WarehouseAddress> _filter(List<WarehouseAddress> list) {
    if (_filterStreet == null) return list;
    return list.where((a) => a.street == _filterStreet).toList();
  }

  Widget _filterChip(String label, String? value, String? current) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => setState(() => _filterStreet = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  void _showForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddressForm(ds: context.read<DataService>()),
    );
  }
}

class _AddressList extends StatelessWidget {
  final List<WarehouseAddress> addresses;
  final DataService ds;
  final bool showLot;
  const _AddressList({required this.addresses, required this.ds, required this.showLot});

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) return EmptyState(icon: Icons.location_on, title: showLot ? 'Nenhum endereço ocupado' : 'Todos os endereços estão ocupados');

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: addresses.length,
      itemBuilder: (context, i) {
        final addr = addresses[i];
        final lot = addr.currentLotId != null ? ds.allLots.where((l) => l.id == addr.currentLotId).firstOrNull : null;
        return GestureDetector(
          onTap: () => _showDetail(context, addr, lot),
          child: Container(
            decoration: BoxDecoration(
              color: addr.isOccupied ? AppTheme.warningLight : AppTheme.successLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: addr.isOccupied ? AppTheme.warning.withValues(alpha: 0.4) : AppTheme.success.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(addr.isOccupied ? Icons.inventory_2 : Icons.add_box_outlined,
                  color: addr.isOccupied ? AppTheme.warning : AppTheme.success, size: 22),
                const SizedBox(height: 4),
                Text(addr.code, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: addr.isOccupied ? AppTheme.warning : AppTheme.success), textAlign: TextAlign.center),
                if (lot != null)
                  Text(lot.productSku, style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, WarehouseAddress addr, Lot? lot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(addr.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Center(
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: addr.barcode,
                width: 250,
                height: 60,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text(addr.barcode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.info, letterSpacing: 2))),
            const SizedBox(height: 16),
            StatusBadge(
              label: addr.isOccupied ? 'OCUPADO' : 'LIVRE',
              color: addr.isOccupied ? AppTheme.warning : AppTheme.success,
            ),
            if (lot != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.inventory_2, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lot.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Lote: ${lot.barcode} • ${lot.currentQuantity} un.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                )),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressForm extends StatefulWidget {
  final DataService ds;
  const _AddressForm({required this.ds});
  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _streetCtrl = TextEditingController();
  final _moduleCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novo Endereço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _f(_streetCtrl, 'Rua')),
            const SizedBox(width: 8),
            Expanded(child: _f(_moduleCtrl, 'Módulo')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _f(_levelCtrl, 'Nível')),
            const SizedBox(width: 8),
            Expanded(child: _f(_posCtrl, 'Posição')),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _loading ? null : _save, child: const Text('Salvar Endereço')),
          ),
        ],
      ),
    );
  }

  Widget _f(TextEditingController c, String l) =>
    TextField(controller: c, decoration: InputDecoration(labelText: l));

  Future<void> _save() async {
    setState(() => _loading = true);
    await widget.ds.addAddress(WarehouseAddress(
      id: widget.ds.newAddressId(),
      street: _streetCtrl.text, module: _moduleCtrl.text,
      level: _levelCtrl.text, position: _posCtrl.text,
    ));
    if (mounted) Navigator.pop(context);
  }
}
