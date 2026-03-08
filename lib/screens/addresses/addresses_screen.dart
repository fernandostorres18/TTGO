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

class _AddressesScreenState extends State<AddressesScreen> {
  String? _selectedStreet;

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final streets = ds.allAddresses.map((a) => a.street).toSet().toList()..sort();
    final total = ds.allAddresses.length;
    final occupied = ds.allAddresses.where((a) => a.isOccupied).length;
    final free = total - occupied;
    final occupancyPct = total > 0 ? occupied / total : 0.0;

    // Filtro por rua
    final currentStreet = _selectedStreet ?? (streets.isNotEmpty ? streets.first : null);
    final byStreet = currentStreet != null
        ? ds.allAddresses.where((a) => a.street == currentStreet).toList()
        : ds.allAddresses;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.location_on, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Mapa do Armazém',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                        tooltip: 'Novo Endereço',
                        onPressed: () => _showForm(context),
                      ),
                    ]),
                    // ── Resumo ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                      child: Row(children: [
                        _HeaderStat(label: 'Total', value: '$total', icon: Icons.grid_view),
                        const SizedBox(width: 20),
                        _HeaderStat(label: 'Ocupados', value: '$occupied', icon: Icons.inventory_2, color: Colors.orange.shade200),
                        const SizedBox(width: 20),
                        _HeaderStat(label: 'Livres', value: '$free', icon: Icons.check_circle_outline, color: Colors.green.shade200),
                      ]),
                    ),
                    // ── Barra de ocupação ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Ocupação: ${(occupancyPct * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text('${(100 - occupancyPct * 100).toStringAsFixed(0)}% disponível',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: occupancyPct,
                                minHeight: 6,
                                backgroundColor: Colors.white24,
                                valueColor: AlwaysStoppedAnimation(
                                  occupancyPct > 0.8 ? Colors.red.shade300
                                      : occupancyPct > 0.6 ? Colors.orange.shade300
                                      : Colors.green.shade300,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // ── Seletor de Rua ──────────────────────────────────────────────
          if (streets.length > 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: streets.map((s) {
                    final isSelected = s == currentStreet;
                    final sAddr = ds.allAddresses.where((a) => a.street == s);
                    final sOcc = sAddr.where((a) => a.isOccupied).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedStreet = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected ? AppTheme.primary : AppTheme.divider),
                            boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
                          ),
                          child: Row(children: [
                            Icon(Icons.warehouse,
                                size: 14,
                                color: isSelected ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Rua $s',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  )),
                              Text('$sOcc/${sAddr.length} ocup.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? Colors.white70 : AppTheme.textHint,
                                  )),
                            ]),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ── Mapa de endereços ───────────────────────────────────────────
          Expanded(
            child: byStreet.isEmpty
                ? const EmptyState(icon: Icons.location_off, title: 'Nenhum endereço cadastrado')
                : _WarehouseMap(
                    addresses: byStreet,
                    ds: ds,
                    streetLabel: currentStreet ?? '',
                  ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddressForm(ds: context.read<DataService>()),
    );
  }
}

// ── Widget de estatística no header ──────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _HeaderStat({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color ?? Colors.white70),
    const SizedBox(width: 4),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ]),
  ]);
}

// ── Mapa visual do armazém ────────────────────────────────────────────────

class _WarehouseMap extends StatelessWidget {
  final List<WarehouseAddress> addresses;
  final DataService ds;
  final String streetLabel;

  const _WarehouseMap({
    required this.addresses,
    required this.ds,
    required this.streetLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupar por módulo
    final modules = <String, List<WarehouseAddress>>{};
    for (final addr in addresses) {
      modules.putIfAbsent(addr.module, () => []).add(addr);
    }
    final sortedModules = modules.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Legenda
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppTheme.success, label: 'Livre'),
              const SizedBox(width: 24),
              _LegendItem(color: AppTheme.warning, label: 'Ocupado'),
            ],
          ),
        ),

        // Módulos
        ...sortedModules.map((module) {
          final modAddresses = modules[module]!;
          // Agrupar por nível dentro do módulo
          final levels = <String, List<WarehouseAddress>>{};
          for (final a in modAddresses) {
            levels.putIfAbsent(a.level, () => []).add(a);
          }
          final sortedLevels = levels.keys.toList()..sort((a, b) => b.compareTo(a)); // nivel mais alto primeiro
          final occInMod = modAddresses.where((a) => a.isOccupied).length;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabeçalho do módulo ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$streetLabel-$module',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Text('Módulo $module',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    const Spacer(),
                    Text('$occInMod/${modAddresses.length} ocupados',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),

                // ── Níveis ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: sortedLevels.map((level) {
                      final levelAddresses = levels[level]!..sort((a, b) => a.position.compareTo(b.position));
                      final levelLabel = switch (level) {
                        '1' => 'Nível 1 (Chão)',
                        '2' => 'Nível 2',
                        '3' => 'Nível 3 (Topo)',
                        _ => 'Nível $level',
                      };

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label do nível
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [
                                Icon(Icons.layers, size: 12, color: AppTheme.textHint),
                                const SizedBox(width: 4),
                                Text(levelLabel,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
                              ]),
                            ),
                            // Posições na linha
                            Row(
                              children: levelAddresses.map((addr) {
                                final lot = addr.currentLotId != null
                                    ? ds.allLots.where((l) => l.id == addr.currentLotId).firstOrNull
                                    : null;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: GestureDetector(
                                      onTap: () => _showDetail(context, addr, lot),
                                      child: _AddressCell(addr: addr, lot: lot),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showDetail(BuildContext context, WarehouseAddress addr, Lot? lot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddressDetailSheet(addr: addr, lot: lot, ds: ds),
    );
  }
}

// ── Célula individual de endereço ─────────────────────────────────────────

class _AddressCell extends StatelessWidget {
  final WarehouseAddress addr;
  final Lot? lot;
  const _AddressCell({required this.addr, this.lot});

  @override
  Widget build(BuildContext context) {
    final isOcc = addr.isOccupied;
    final bg = isOcc ? AppTheme.warningLight : AppTheme.successLight;
    final border = isOcc ? AppTheme.warning.withValues(alpha: 0.5) : AppTheme.success.withValues(alpha: 0.4);
    final textColor = isOcc ? AppTheme.warning : AppTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOcc ? Icons.inventory_2 : Icons.add_box_outlined,
            size: 20,
            color: textColor,
          ),
          const SizedBox(height: 4),
          Text(
            addr.position,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          if (lot != null) ...[
            const SizedBox(height: 2),
            Text(
              lot!.productSku,
              style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              '${lot!.currentQuantity} un.',
              style: TextStyle(fontSize: 8, color: AppTheme.success, fontWeight: FontWeight.w600),
            ),
          ] else
            Text(
              'LIVRE',
              style: TextStyle(fontSize: 8, color: AppTheme.success, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}

// ── Legenda ───────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
    ),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
  ]);
}

// ── Sheet de detalhe ──────────────────────────────────────────────────────

class _AddressDetailSheet extends StatelessWidget {
  final WarehouseAddress addr;
  final Lot? lot;
  final DataService ds;
  const _AddressDetailSheet({required this.addr, required this.lot, required this.ds});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Título
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: addr.isOccupied ? AppTheme.warningLight : AppTheme.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                addr.isOccupied ? Icons.inventory_2 : Icons.check_circle_outline,
                color: addr.isOccupied ? AppTheme.warning : AppTheme.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(addr.displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              StatusBadge(
                label: addr.isOccupied ? 'OCUPADO' : 'LIVRE',
                color: addr.isOccupied ? AppTheme.warning : AppTheme.success,
                bgColor: addr.isOccupied ? AppTheme.warningLight : AppTheme.successLight,
              ),
            ]),
          ]),

          const SizedBox(height: 20),

          // Código de barras
          Center(
            child: BarcodeWidget(
              barcode: Barcode.code128(),
              data: addr.barcode,
              width: 260,
              height: 55,
              style: const TextStyle(fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(addr.barcode,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.info, letterSpacing: 2, fontSize: 12)),
          ),

          // Lote vinculado
          if (lot != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.inventory_2, size: 20, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lot!.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('SKU: ${lot!.productSku}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.qr_code, size: 12, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text('Lote: ${lot!.barcode}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${lot!.currentQuantity} un.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),
          // Info de estrutura
          Row(children: [
            _InfoChip(icon: Icons.warehouse, label: 'Rua ${addr.street}'),
            const SizedBox(width: 8),
            _InfoChip(icon: Icons.view_module, label: 'Módulo ${addr.module}'),
            const SizedBox(width: 8),
            _InfoChip(icon: Icons.layers, label: 'Nível ${addr.level}'),
            const SizedBox(width: 8),
            _InfoChip(icon: Icons.grid_on, label: 'Pos. ${addr.position}'),
          ]),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Formulário de novo endereço ───────────────────────────────────────────

class _AddressForm extends StatefulWidget {
  final DataService ds;
  const _AddressForm({required this.ds});
  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _streetCtrl  = TextEditingController();
  final _moduleCtrl  = TextEditingController();
  final _levelCtrl   = TextEditingController();
  final _posCtrl     = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _streetCtrl.dispose(); _moduleCtrl.dispose();
    _levelCtrl.dispose(); _posCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Row(children: [
            Icon(Icons.add_location_alt, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Novo Endereço', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          const Text('Formato: Rua A • Módulo 01 • Nível 1 • Posição 01  →  A-01-1-01',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _field(_streetCtrl, 'Rua', 'Ex: A', Icons.warehouse)),
            const SizedBox(width: 10),
            Expanded(child: _field(_moduleCtrl, 'Módulo', 'Ex: 01', Icons.view_module)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_levelCtrl, 'Nível', 'Ex: 1', Icons.layers)),
            const SizedBox(width: 10),
            Expanded(child: _field(_posCtrl, 'Posição', 'Ex: 01', Icons.grid_on)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_loading ? 'Salvando...' : 'Salvar Endereço'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon) =>
      TextField(
        controller: c,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );

  Future<void> _save() async {
    if (_streetCtrl.text.trim().isEmpty || _moduleCtrl.text.trim().isEmpty ||
        _levelCtrl.text.trim().isEmpty || _posCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos'), backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _loading = true);
    await widget.ds.addAddress(WarehouseAddress(
      id: widget.ds.newAddressId(),
      street:   _streetCtrl.text.trim().toUpperCase(),
      module:   _moduleCtrl.text.trim(),
      level:    _levelCtrl.text.trim(),
      position: _posCtrl.text.trim(),
    ));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço adicionado!'), backgroundColor: AppTheme.success),
      );
    }
  }
}
