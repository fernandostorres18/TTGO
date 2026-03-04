// lib/screens/clients/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../orders/orders_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    var clients = ds.clients;
    if (_search.isNotEmpty) {
      clients = clients.where((c) =>
        c.companyName.toLowerCase().contains(_search) ||
        c.cnpjCpf.contains(_search)).toList();
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
                        const Icon(Icons.business, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Clientes', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          onPressed: () => _showClientForm(context, null),
                        ),
                      ],
                    ),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome ou CNPJ...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Stats row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _statChip('Total: ${clients.length}', AppTheme.primary),
                const SizedBox(width: 8),
                _statChip('Ativos: ${clients.where((c) => c.status == ClientStatus.ativo).length}', AppTheme.success),
                const SizedBox(width: 8),
                _statChip('Inativos: ${clients.where((c) => c.status == ClientStatus.inativo).length}', AppTheme.textSecondary),
              ],
            ),
          ),
          Expanded(
            child: clients.isEmpty
              ? EmptyState(icon: Icons.business, title: 'Nenhum cliente encontrado', actionLabel: 'Adicionar Cliente', onAction: () => _showClientForm(context, null))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: clients.length,
                  itemBuilder: (context, i) => _ClientCard(client: clients[i], index: i, ds: ds, onEdit: () => _showClientForm(context, clients[i])),
                ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );

  void _showClientForm(BuildContext context, Client? client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClientFormSheet(client: client, ds: context.read<DataService>()),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Client client;
  final int index;
  final DataService ds;
  final VoidCallback onEdit;
  const _ClientCard({required this.client, required this.index, required this.ds, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final orders = ds.getOrdersByClient(client.id);
    final lots = ds.getLotsByClient(client.id);
    final activeOrders = orders.where((o) => o.status != OrderStatus.finalizado).length;
    final isActive = client.status == ClientStatus.ativo;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClientAvatar(initials: client.initials, colorIndex: index, photoUrl: client.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('CNPJ: ${client.cnpjCpf}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: isActive ? 'ATIVO' : 'INATIVO',
                      color: isActive ? AppTheme.success : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(label: client.contractPlan, color: AppTheme.info),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _info(Icons.person_outlined, client.responsibleName),
                const SizedBox(width: 12),
                _info(Icons.phone_outlined, client.phone),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _metricBubble('Pedidos\nAtivos', '$activeOrders', AppTheme.warning),
                const SizedBox(width: 8),
                _metricBubble('Lotes\nArmazém', '${lots.length}', AppTheme.info),
                const SizedBox(width: 8),
                _metricBubble('Mínimo\nMensal', formatCurrency(client.minimumMonthly), AppTheme.primary),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Pedidos'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _confirmDelete(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    side: const BorderSide(color: AppTheme.error),
                    foregroundColor: AppTheme.error,
                  ),
                  child: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.error),
            SizedBox(width: 10),
            Text('Excluir Cliente'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja excluir o cliente "${client.companyName}"?'),
            const SizedBox(height: 8),
            const Text(
              'Atenção: não é possível excluir clientes com pedidos em aberto.',
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
              final ok = await ds.deleteClient(client.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Cliente "${client.companyName}" excluído com sucesso.'
                      : 'Não foi possível excluir: cliente possui pedidos em aberto.'),
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

  Widget _info(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    ],
  );

  Widget _metricBubble(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ─── CLIENT FORM ──────────────────────────────────────────────────────────

class _ClientFormSheet extends StatefulWidget {
  final Client? client;
  final DataService ds;
  const _ClientFormSheet({this.client, required this.ds});
  @override
  State<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<_ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.client?.companyName);
  late final _cnpjCtrl = TextEditingController(text: widget.client?.cnpjCpf);
  late final _respCtrl = TextEditingController(text: widget.client?.responsibleName);
  late final _phoneCtrl = TextEditingController(text: widget.client?.phone);
  late final _emailCtrl = TextEditingController(text: widget.client?.email);
  late final _planCtrl = TextEditingController(text: widget.client?.contractPlan ?? 'Básico');
  late final _minCtrl = TextEditingController(text: widget.client?.minimumMonthly.toString() ?? '1000');
  late final _smallCtrl = TextEditingController(text: widget.client?.priceSmallOrder.toString() ?? '6');
  late final _medCtrl = TextEditingController(text: widget.client?.priceMediumOrder.toString() ?? '12');
  late final _largeCtrl = TextEditingController(text: widget.client?.priceLargeOrder.toString() ?? '20');
  late final _envCtrl = TextEditingController(text: widget.client?.priceEnvelopeOrder.toString() ?? '5');
  late final _photoCtrl = TextEditingController(text: widget.client?.photoUrl ?? '');
  ClientStatus _status = ClientStatus.ativo;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.client?.status ?? ClientStatus.ativo;
  }

  @override
  Widget build(BuildContext context) {
    final photoPreview = _photoCtrl.text.isNotEmpty ? _photoCtrl.text : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com foto preview
              Row(
                children: [
                  Expanded(
                    child: Text(widget.client == null ? 'Novo Cliente' : 'Editar Cliente',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  // Preview da foto
                  GestureDetector(
                    onTap: () => _showPhotoDialog(context),
                    child: Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: photoPreview != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(
                                    photoPreview,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.business, color: AppTheme.primary, size: 28),
                                  ),
                                )
                              : const Icon(Icons.add_a_photo, color: AppTheme.primary, size: 26),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field(_nameCtrl, 'Empresa *', Icons.business),
              const SizedBox(height: 10),
              _field(_cnpjCtrl, 'CNPJ/CPF *', Icons.badge),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_respCtrl, 'Responsável', Icons.person)),
                const SizedBox(width: 10),
                Expanded(child: _field(_phoneCtrl, 'Telefone', Icons.phone)),
              ]),
              const SizedBox(height: 10),
              _field(_emailCtrl, 'E-mail', Icons.email),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_planCtrl, 'Plano', Icons.card_membership)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<ClientStatus>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.toggle_on, size: 18)),
                    items: ClientStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s == ClientStatus.ativo ? 'Ativo' : 'Inativo'),
                    )).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              const Text('Tabela de Preços', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _field(_minCtrl, 'Mínimo Mensal (R\$)', Icons.calendar_month),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(_smallCtrl, 'Pequeno (R\$)', Icons.inbox)),
                const SizedBox(width: 8),
                Expanded(child: _field(_medCtrl, 'Médio (R\$)', Icons.inventory_2)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(_largeCtrl, 'Grande (R\$)', Icons.all_inbox)),
                const SizedBox(width: 8),
                Expanded(child: _field(_envCtrl, 'Envelope (R\$)', Icons.mail_outline)),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? 'Salvando...' : 'Salvar Cliente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType? type}) =>
    TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18)),
    );

  void _showPhotoDialog(BuildContext context) {
    final tempCtrl = TextEditingController(text: _photoCtrl.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_a_photo, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Foto do Cliente', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            if (_photoCtrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _photoCtrl.text,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image, size: 60, color: AppTheme.textHint),
                  ),
                ),
              ),
            TextField(
              controller: tempCtrl,
              decoration: const InputDecoration(
                labelText: 'URL da foto (https://...)',
                hintText: 'Cole o link da imagem aqui',
                prefixIcon: Icon(Icons.link, size: 18),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cole a URL de uma imagem (logo da empresa, etc.)',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          if (_photoCtrl.text.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _photoCtrl.clear());
                Navigator.pop(context);
              },
              child: const Text('Remover foto', style: TextStyle(color: AppTheme.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _photoCtrl.text = tempCtrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final photo = _photoCtrl.text.trim().isNotEmpty ? _photoCtrl.text.trim() : null;
    if (widget.client == null) {
      final client = Client(
        id: widget.ds.newClientId(),
        companyName: _nameCtrl.text,
        cnpjCpf: _cnpjCtrl.text,
        responsibleName: _respCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        contractPlan: _planCtrl.text,
        minimumMonthly: double.tryParse(_minCtrl.text) ?? 0,
        priceSmallOrder: double.tryParse(_smallCtrl.text) ?? 0,
        priceMediumOrder: double.tryParse(_medCtrl.text) ?? 0,
        priceLargeOrder: double.tryParse(_largeCtrl.text) ?? 0,
        priceEnvelopeOrder: double.tryParse(_envCtrl.text) ?? 5,
        status: _status,
        createdAt: DateTime.now(),
        photoUrl: photo,
      );
      await widget.ds.addClient(client);
    } else {
      widget.client!.companyName = _nameCtrl.text;
      widget.client!.cnpjCpf = _cnpjCtrl.text;
      widget.client!.responsibleName = _respCtrl.text;
      widget.client!.phone = _phoneCtrl.text;
      widget.client!.email = _emailCtrl.text;
      widget.client!.contractPlan = _planCtrl.text;
      widget.client!.minimumMonthly = double.tryParse(_minCtrl.text) ?? 0;
      widget.client!.priceSmallOrder = double.tryParse(_smallCtrl.text) ?? 0;
      widget.client!.priceMediumOrder = double.tryParse(_medCtrl.text) ?? 0;
      widget.client!.priceLargeOrder = double.tryParse(_largeCtrl.text) ?? 0;
      widget.client!.priceEnvelopeOrder = double.tryParse(_envCtrl.text) ?? 5;
      widget.client!.status = _status;
      widget.client!.photoUrl = photo;
      await widget.ds.updateClient(widget.client!);
    }
    if (mounted) Navigator.pop(context);
  }
}
