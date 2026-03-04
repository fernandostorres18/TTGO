// lib/screens/history/global_history_screen.dart
// Histórico Global — todos os eventos do sistema com busca avançada

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../orders/orders_screen.dart';

String _formatDateTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Agora mesmo';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays == 1) return 'Ontem ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class GlobalHistoryScreen extends StatefulWidget {
  const GlobalHistoryScreen({super.key});

  @override
  State<GlobalHistoryScreen> createState() => _GlobalHistoryScreenState();
}

class _GlobalHistoryScreenState extends State<GlobalHistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _filterAction; // null = todos

  static const _actionFilters = [
    {'label': 'Todos', 'value': null},
    {'label': 'Criados', 'value': 'criado'},
    {'label': 'Separação', 'value': 'separacao_iniciada'},
    {'label': 'Sep. Concluída', 'value': 'separacao_concluida'},
    {'label': 'Faturado', 'value': 'faturado'},
    {'label': 'Enviado', 'value': 'enviado'},
    {'label': 'Finalizado', 'value': 'finalizado'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    var events = ds.getGlobalEvents();

    // Filtro por ação
    if (_filterAction != null) {
      events = events.where((e) => e.event.action == _filterAction).toList();
    }

    // Filtro por busca
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      events = events.where((e) =>
          e.event.description.toLowerCase().contains(q) ||
          e.event.userName.toLowerCase().contains(q) ||
          e.clientName.toLowerCase().contains(q) ||
          e.invoiceNumber.toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
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
                          const SizedBox(width: 4),
                        const Icon(Icons.timeline, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Histórico Global',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              Text('Todos os eventos do sistema',
                                  style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        // Total badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${events.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  // Barra de pesquisa
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v.toLowerCase()),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar por usuário, cliente, NF, ação...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  // Filtros de ação
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _actionFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final f = _actionFilters[i];
                        final selected = _filterAction == f['value'];
                        return GestureDetector(
                          onTap: () => setState(() => _filterAction = f['value']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(f['label'] as String,
                                style: TextStyle(
                                    color: selected ? AppTheme.primary : Colors.white,
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // ── Lista de eventos ───────────────────────────────────────────────
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 60,
                            color: AppTheme.textHint.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('Nenhum evento encontrado',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 15)),
                        if (_search.isNotEmpty || _filterAction != null) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _search = '';
                                _filterAction = null;
                              });
                            },
                            child: const Text('Limpar filtros'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      return _GlobalEventCard(
                        ge: events[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: events[i].orderId),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── CARD DE EVENTO GLOBAL ────────────────────────────────────────────────

class _GlobalEventCard extends StatelessWidget {
  final GlobalEvent ge;
  final VoidCallback onTap;
  const _GlobalEventCard({required this.ge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(ge.event.action);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: ícone + descrição + seta
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_actionIcon(ge.event.action), size: 15, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ge.event.description,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppTheme.textHint),
              ],
            ),
            const SizedBox(height: 8),
            // Linha 2: usuário + cliente
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(ge.event.userName,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(ge.clientName,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Linha 3: NF + horário
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 13, color: AppTheme.textHint),
                const SizedBox(width: 3),
                Text('NF ${ge.invoiceNumber}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textHint)),
                const SizedBox(width: 12),
                const Icon(Icons.schedule, size: 13, color: AppTheme.textHint),
                const SizedBox(width: 3),
                Text(_formatDateTime(ge.event.date),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'criado': return Icons.add_circle_outline;
      case 'separacao_iniciada': return Icons.content_cut;
      case 'separacao_concluida': return Icons.check_circle_outline;
      case 'faturado': return Icons.receipt;
      case 'enviado': return Icons.local_shipping;
      case 'finalizado': return Icons.done_all;
      default: return Icons.update;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'criado': return AppTheme.info;
      case 'separacao_iniciada': return AppTheme.warning;
      case 'separacao_concluida': return AppTheme.success;
      case 'faturado': return AppTheme.primary;
      case 'enviado': return Colors.indigo;
      case 'finalizado': return AppTheme.statusFinalizado;
      default: return AppTheme.textSecondary;
    }
  }
}
