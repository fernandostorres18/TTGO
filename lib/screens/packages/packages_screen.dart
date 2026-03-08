// lib/screens/packages/packages_screen.dart
// Tela para gerenciar tipos de embalagens (editável por admin)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Tipos de Embalagem',
            subtitle: 'Caixas, envelopes e outros',
            showBack: true,
          ),
          Expanded(
            child: ds.allPackageTypes.isEmpty
                ? const Center(child: Text('Nenhuma embalagem cadastrada'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: ds.allPackageTypes.length,
                    itemBuilder: (ctx, i) => _PackageCard(
                      pkg: ds.allPackageTypes[i],
                      ds: ds,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: ds.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(context, ds, null),
              icon: const Icon(Icons.add),
              label: const Text('Nova Embalagem'),
              backgroundColor: AppTheme.primary,
            )
          : null,
    );
  }

  void _showForm(BuildContext context, DataService ds, PackageType? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageForm(ds: ds, existing: existing),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final PackageType pkg;
  final DataService ds;
  const _PackageCard({required this.pkg, required this.ds});

  IconData get _icon {
    final n = pkg.name.toLowerCase();
    if (n.contains('envelope')) return Icons.mail_outline;
    if (n.contains('grande')) return Icons.all_inbox;
    if (n.contains('médio') || n.contains('medio')) return Icons.inventory_2;
    return Icons.inbox;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (pkg.isActive ? AppTheme.primary : AppTheme.textHint).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon,
                  color: pkg.isActive ? AppTheme.primary : AppTheme.textHint, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(pkg.name,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: pkg.isActive ? AppTheme.textPrimary : AppTheme.textHint)),
                      if (!pkg.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.textHint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('INATIVO',
                              style: TextStyle(fontSize: 9, color: AppTheme.textHint)),
                        ),
                      ],
                    ],
                  ),
                  if (pkg.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(pkg.description,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _dim('Peso máx.', '${pkg.maxWeightKg} kg'),
                      if (pkg.maxLengthCm > 0) _dim('Comp.', '${pkg.maxLengthCm.toInt()} cm'),
                      if (pkg.maxWidthCm > 0) _dim('Larg.', '${pkg.maxWidthCm.toInt()} cm'),
                      if (pkg.maxHeightCm > 0) _dim('Alt.', '${pkg.maxHeightCm.toInt()} cm'),
                    ],
                  ),
                ],
              ),
            ),
            if (ds.isAdmin)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textHint, size: 20),
                onSelected: (action) async {
                  if (action == 'edit') {
                    _showEditForm(context, ds, pkg);
                  } else if (action == 'toggle') {
                    pkg.isActive = !pkg.isActive;
                    await ds.updatePackageType(pkg);
                  } else if (action == 'delete') {
                    _confirmDelete(context, ds, pkg);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(
                    leading: Icon(Icons.edit, size: 18), title: Text('Editar'), dense: true)),
                  PopupMenuItem(value: 'toggle', child: ListTile(
                    leading: Icon(pkg.isActive ? Icons.visibility_off : Icons.visibility, size: 18),
                    title: Text(pkg.isActive ? 'Desativar' : 'Ativar'), dense: true)),
                  const PopupMenuItem(value: 'delete', child: ListTile(
                    leading: Icon(Icons.delete, color: AppTheme.error, size: 18),
                    title: Text('Excluir', style: TextStyle(color: AppTheme.error)), dense: true)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _dim(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text('$label: $value',
        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
  );

  void _showEditForm(BuildContext context, DataService ds, PackageType pkg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageForm(ds: ds, existing: pkg),
    );
  }

  void _confirmDelete(BuildContext context, DataService ds, PackageType pkg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Embalagem'),
        content: Text('Deseja excluir "${pkg.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              await ds.deletePackageType(pkg.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PackageForm extends StatefulWidget {
  final DataService ds;
  final PackageType? existing;
  const _PackageForm({required this.ds, this.existing});
  @override
  State<_PackageForm> createState() => _PackageFormState();
}

class _PackageFormState extends State<_PackageForm> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description;
      _weightCtrl.text = '${p.maxWeightKg}';
      _lengthCtrl.text = p.maxLengthCm > 0 ? '${p.maxLengthCm.toInt()}' : '';
      _widthCtrl.text = p.maxWidthCm > 0 ? '${p.maxWidthCm.toInt()}' : '';
      _heightCtrl.text = p.maxHeightCm > 0 ? '${p.maxHeightCm.toInt()}' : '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _weightCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(isEdit ? Icons.edit : Icons.add, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Text(isEdit ? 'Editar Embalagem' : 'Nova Embalagem',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome da embalagem *',
                prefixIcon: Icon(Icons.label),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                prefixIcon: Icon(Icons.description),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightCtrl,
              decoration: const InputDecoration(
                labelText: 'Peso máximo (kg) *',
                prefixIcon: Icon(Icons.scale),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            const Text('Dimensões (cm)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: _lengthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Comprimento',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _widthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Largura',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _heightCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Altura',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                )),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isEdit ? Icons.save : Icons.add, color: Colors.white, size: 18),
                label: Text(isEdit ? 'Salvar' : 'Adicionar',
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _weightCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome e peso máximo.')));
      return;
    }
    setState(() => _loading = true);

    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 1.0;
    final length = double.tryParse(_lengthCtrl.text.trim()) ?? 0;
    final width = double.tryParse(_widthCtrl.text.trim()) ?? 0;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 0;

    if (widget.existing != null) {
      final p = widget.existing!;
      p.name = _nameCtrl.text.trim();
      p.description = _descCtrl.text.trim();
      p.maxWeightKg = weight;
      p.maxLengthCm = length;
      p.maxWidthCm = width;
      p.maxHeightCm = height;
      await widget.ds.updatePackageType(p);
    } else {
      await widget.ds.addPackageType(PackageType(
        id: widget.ds.newPackageTypeId(),
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        maxWeightKg: weight,
        maxLengthCm: length,
        maxWidthCm: width,
        maxHeightCm: height,
        createdAt: DateTime.now(),
      ));
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing != null ? 'Embalagem atualizada!' : 'Embalagem adicionada!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }
}
