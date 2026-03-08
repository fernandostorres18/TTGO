// lib/screens/support/support_screen.dart
// Chat  = conversa cliente ↔ suporte (atendente aceita, encerra, cliente avalia)
// Chamado = ticket interno aberto pelo suporte (admin aprova / recusa)

import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../notifications/notifications_screen.dart' show SoundHelper;
import '../../core/theme/app_theme.dart';
import '../orders/orders_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Contagem anterior de mensagens de clientes para detectar novas
  int _prevClientMsgCount = 0;

  // Quantas abas cada perfil tem:
  // Admin        : Chat | Chamados | Devoluções | Avaliações  (4)
  // SupportAgent : Chat | Chamados | Devoluções               (3)
  // Operator     : Chamados | Devoluções                      (2)
  // Client       : Chat                                       (1)
  int _tabCount(DataService ds) {
    if (ds.isAdmin) return 4;
    if (ds.isSupportAgent) return 3;
    if (ds.isOperator) return 2;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    final ds = context.read<DataService>();
    _tab = TabController(length: _tabCount(ds), vsync: this);
    // Inicializa contagem base para não tocar som na primeira carga
    _prevClientMsgCount = _countClientMessages(ds);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _manualRefresh() => setState(() {});

  int _countClientMessages(DataService ds) {
    return ds.allTickets.fold(0, (sum, t) =>
        sum + t.messages.where((m) => m.senderRole == UserRole.client && !m.isSystem).length);
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final isAdmin = ds.isAdmin;
    final isAgent = ds.isSupportAgent;
    final isStaff = ds.isStaff;

    // Som: toca apenas quando chegam novas mensagens de clientes (staff vê o chat)
    if (isStaff) {
      final current = _countClientMessages(ds);
      if (current > _prevClientMsgCount) {
        _prevClientMsgCount = current;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SoundHelper.playNotification();
        });
      } else {
        _prevClientMsgCount = current;
      }
    }

    // Operador NÃO vê a aba Chat
    final showChat = isAdmin || isAgent || !isStaff;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(children: [
        // ── Header ────────────────────────────────────────────────────
        Container(
          decoration: AppTheme.headerGradient,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
                child: Row(children: [
                  // Botão voltar apenas se houver rota anterior
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 8),
                  const Icon(Icons.support_agent, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Suporte',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(
                            isStaff
                                ? 'Atendimento e gestão de chamados'
                                : 'Fale com o suporte',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ]),
                  ),
                  // Botão de atualizar manual (todos os usuários)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    onPressed: _manualRefresh,
                    tooltip: 'Atualizar',
                  ),
                  // Admin: toggle online/offline + configurações de horário
                  if (isAdmin) ...[
                    // Toggle online/offline
                    GestureDetector(
                      onTap: () async {
                        final s = ds.supportSettings;
                        s.isOnline = !s.isOnline;
                        await ds.updateSupportSettings(s);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: ds.supportSettings.isOnline
                              ? AppTheme.success.withValues(alpha: 0.25)
                              : AppTheme.error.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ds.supportSettings.isOnline
                                ? AppTheme.success.withValues(alpha: 0.6)
                                : AppTheme.error.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ds.supportSettings.isOnline
                                  ? AppTheme.success
                                  : AppTheme.error,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ds.supportSettings.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ds.supportSettings.isOnline
                                  ? AppTheme.success
                                  : AppTheme.error,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.settings,
                          color: Colors.white70, size: 20),
                      onPressed: () => _showSettings(context, ds),
                      tooltip: 'Configurações de atendimento',
                    ),
                  ],
                ]),
              ),
              TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                isScrollable: isStaff,
                tabs: [
                  // Chat: admin, atendente e cliente (NÃO operador)
                  if (showChat)
                    const Tab(
                        icon: Icon(Icons.chat_bubble_outline, size: 16),
                        text: 'Chat'),
                  if (isStaff) ...[
                    const Tab(
                        icon: Icon(Icons.assignment_outlined, size: 16),
                        text: 'Chamados'),
                    const Tab(
                        icon: Icon(Icons.assignment_return_outlined, size: 16),
                        text: 'Devoluções'),
                    if (isAdmin)
                      const Tab(
                          icon: Icon(Icons.bar_chart, size: 16),
                          text: 'Avaliações'),
                  ],
                ],
              ),
            ]),
          ),
        ),

        // ── Conteúdo ──────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              if (showChat) _ChatTab(isStaff: isStaff),
              if (isStaff) ...[
                _TicketListTab(isReturn: false),
                _TicketListTab(isReturn: true),
                if (isAdmin) const _AgentStatsTab(),
              ],
            ],
          ),
        ),
      ]),

      // FAB: staff abre novo chamado
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _openNewTicket(context, ds),
              icon: const Icon(Icons.assignment_add),
              label: const Text('Novo Chamado'),
              backgroundColor: AppTheme.primary,
            )
          : null,
    );
  }

  void _openNewTicket(BuildContext context, DataService ds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewTicketSheet(ds: ds),
    );
  }

  void _showSettings(BuildContext context, DataService ds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupportSettingsSheet(ds: ds),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ABA CHAT
// ═════════════════════════════════════════════════════════════════════════════

class _ChatTab extends StatelessWidget {
  final bool isStaff;
  const _ChatTab({required this.isStaff});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();

    if (!isStaff) {
      // CLIENTE: lista dos seus chats
      return _ClientChatListView(ds: ds);
    }

    // STAFF: lista de chats disponíveis (aceitar) ou atribuídos a mim
    final chats = ds.getAvailableChats()
        .where((t) => _isChatTicket(t))
        .toList();

    if (chats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('Nenhuma conversa ativa',
                style:
                    TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
            SizedBox(height: 6),
            Text('Conversas de clientes aparecerão aqui',
                style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _StaffChatCard(
        ticket: chats[i],
        currentUserId: ds.currentUser?.id ?? '',
        isAdmin: ds.isAdmin,
      ),
    );
  }

  bool _isChatTicket(SupportTicket t) {
    // Tickets criados por funcionários NUNCA são chat — são chamados internos
    if (t.createdByStaff) return false;
    final subjectLower = t.subject.toLowerCase();
    if (subjectLower.contains('chat')) return true;
    final chamadoCats = {
      TicketCategory.return_product,
      TicketCategory.damage,
      TicketCategory.complaint,
      TicketCategory.shipping,
      TicketCategory.billing,
      TicketCategory.technical,
      TicketCategory.stock,
    };
    return !chamadoCats.contains(t.category);
  }
}

// ─── Card de chat para staff ──────────────────────────────────────────────────

class _StaffChatCard extends StatelessWidget {
  final SupportTicket ticket;
  final String currentUserId;
  final bool isAdmin;
  const _StaffChatCard(
      {required this.ticket,
      required this.currentUserId,
      required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final lastMsg =
        ticket.messages.isNotEmpty ? ticket.messages.last : null;
    final isAssignedToMe = ticket.assignedToUserId == currentUserId;
    final isUnassigned = ticket.assignedToUserId == null;
    final isOpen = ticket.status == TicketStatus.open ||
        ticket.status == TicketStatus.inProgress;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssignedToMe
              ? AppTheme.primary.withValues(alpha: 0.4)
              : isUnassigned
                  ? AppTheme.warning.withValues(alpha: 0.4)
                  : AppTheme.divider,
          width: isAssignedToMe ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        InkWell(
          onTap: isAssignedToMe || isAdmin
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TicketDetailScreen(ticket: ticket, isChat: true),
                    ),
                  )
              : null,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                backgroundColor: isAssignedToMe
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : AppTheme.divider,
                radius: 22,
                child: Text(
                  ticket.clientName.isNotEmpty
                      ? ticket.clientName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAssignedToMe
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(ticket.clientName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                        if (lastMsg != null)
                          Text(_timeAgo(lastMsg.sentAt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textHint)),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        lastMsg?.text ?? 'Sem mensagens',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (isUnassigned)
                          _badge('Aguardando', AppTheme.warning)
                        else if (isAssignedToMe)
                          _badge('Meu atendimento', AppTheme.primary)
                        else
                          _badge(
                              'Com ${ticket.assignedToUserName ?? "outro"}',
                              AppTheme.textHint),
                        const SizedBox(width: 6),
                        _badge(
                            isOpen ? 'Aberto' : 'Encerrado',
                            isOpen ? AppTheme.success : AppTheme.textHint),
                      ]),
                    ]),
              ),
            ]),
          ),
        ),

        // Botão ACEITAR — aparece apenas se não tem atribuição E usuário é agente/não-admin
        if (isUnassigned && !isAdmin)
          Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppTheme.divider)),
            ),
            child: TextButton.icon(
              onPressed: () async {
                await context.read<DataService>().acceptChat(ticket.id);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TicketDetailScreen(ticket: ticket, isChat: true),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline,
                  size: 16, color: AppTheme.success),
              label: const Text('Aceitar Atendimento',
                  style:
                      TextStyle(color: AppTheme.success, fontSize: 13)),
            ),
          ),

        // Botão ACEITAR para admin também (se não tiver atribuição)
        if (isUnassigned && isAdmin)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: TextButton.icon(
              onPressed: () async {
                await context.read<DataService>().acceptChat(ticket.id);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TicketDetailScreen(ticket: ticket, isChat: true),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline,
                  size: 16, color: AppTheme.primary),
              label: const Text('Aceitar / Abrir Chat',
                  style:
                      TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
          ),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold)),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─── CLIENTE: Lista de chats ──────────────────────────────────────────────────

class _ClientChatListView extends StatelessWidget {
  final DataService ds;
  const _ClientChatListView({required this.ds});

  @override
  Widget build(BuildContext context) {
    final clientId = ds.currentUser?.clientId ?? ds.currentUser?.id ?? '';
    final myChats = ds.allTickets
        .where((t) => t.clientId == clientId && !t.isReturnRequest)
        .toList()
      ..sort((a, b) =>
          (b.updatedAt ?? b.createdAt)
              .compareTo(a.updatedAt ?? a.createdAt));

    return Stack(
      children: [
        myChats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 56,
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('Nenhuma conversa ainda',
                        style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    const Text('Toque em + para falar com o suporte',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: myChats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final ticket = myChats[i];
                  final lastMsg = ticket.messages.isNotEmpty
                      ? ticket.messages.last
                      : null;
                  final isOpen = ticket.status == TicketStatus.open ||
                      ticket.status == TicketStatus.inProgress;
                  final canRate = ticket.status == TicketStatus.resolved &&
                      ticket.rating == null;

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketDetailScreen(
                            ticket: ticket, isChat: true),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: canRate
                              ? AppTheme.warning.withValues(alpha: 0.5)
                              : isOpen
                                  ? AppTheme.primary
                                      .withValues(alpha: 0.3)
                                  : AppTheme.divider,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: isOpen
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : AppTheme.divider,
                          radius: 20,
                          child: Icon(
                            Icons.support_agent,
                            color: isOpen
                                ? AppTheme.primary
                                : AppTheme.textHint,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(ticket.subject,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ),
                                  Text(
                                    _timeAgo(lastMsg?.sentAt ??
                                        ticket.createdAt),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textHint),
                                  ),
                                ]),
                                const SizedBox(height: 3),
                                Text(
                                  lastMsg?.text ?? 'Sem mensagens',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (canRate) ...[
                                  const SizedBox(height: 4),
                                  const Text('⭐ Avalie este atendimento',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.warning,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ]),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: canRate
                                ? AppTheme.warning.withValues(alpha: 0.12)
                                : isOpen
                                    ? AppTheme.success
                                        .withValues(alpha: 0.12)
                                    : AppTheme.divider,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            canRate
                                ? 'Avaliar'
                                : isOpen
                                    ? 'Aberto'
                                    : 'Encerrado',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: canRate
                                  ? AppTheme.warning
                                  : isOpen
                                      ? AppTheme.success
                                      : AppTheme.textHint,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),

        // FAB: Nova Conversa
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openNewChat(context),
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Nova Conversa'),
            backgroundColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _openNewChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewClientChatSheet(ds: ds),
    );
  }
}

// ─── Modal: Cliente inicia nova conversa ─────────────────────────────────────

class _NewClientChatSheet extends StatefulWidget {
  final DataService ds;
  const _NewClientChatSheet({required this.ds});

  @override
  State<_NewClientChatSheet> createState() => _NewClientChatSheetState();
}

class _NewClientChatSheetState extends State<_NewClientChatSheet> {
  final _msgCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _createChat() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);

    final ds = widget.ds;
    final user = ds.currentUser!;
    final client = ds.clients
        .where((c) => c.id == (user.clientId ?? ''))
        .firstOrNull;

    try {
      final ticket = await ds.createTicket(
        clientId: user.clientId ?? user.id,
        clientName: client?.companyName ?? user.name,
        createdByUserId: user.id,
        createdByUserName: user.name,
        category: TicketCategory.other,
        subject: 'Chat com suporte',
        firstMessage: text,
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TicketDetailScreen(ticket: ticket, isChat: true),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Icon(Icons.add_comment_outlined, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Nova Conversa com Suporte',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _msgCtrl,
              maxLines: 4,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Descreva sua dúvida ou problema...',
                hintStyle: const TextStyle(color: AppTheme.textHint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _createChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Enviar'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ABA CHAMADOS / DEVOLUÇÕES  (com filtros Aguardando / Aprovados / Recusados)
// ═════════════════════════════════════════════════════════════════════════════

class _TicketListTab extends StatefulWidget {
  final bool isReturn;
  const _TicketListTab({required this.isReturn});
  @override
  State<_TicketListTab> createState() => _TicketListTabState();
}

class _TicketListTabState extends State<_TicketListTab> {
  // 0=Aguardando, 1=Aprovados, 2=Recusados
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();

    // Categorias que pertencem a chamados
    const chamadoCats = {
      TicketCategory.damage,
      TicketCategory.complaint,
      TicketCategory.shipping,
      TicketCategory.billing,
      TicketCategory.technical,
      TicketCategory.stock,
    };

    List<SupportTicket> allTickets;
    if (widget.isReturn) {
      allTickets = ds.allTickets
          .where((t) => t.category == TicketCategory.return_product)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      allTickets = ds.allTickets
          .where((t) => chamadoCats.contains(t.category))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Para não-admin: só vê os chamados que criou ou que foram atribuídos a ele
    if (!ds.isAdmin) {
      allTickets = allTickets
          .where((t) =>
              t.createdByUserId == ds.currentUser?.id ||
              t.assignedToUserId == ds.currentUser?.id)
          .toList();
    }

    final waiting =
        allTickets.where((t) => !t.adminApproved && !t.adminRejected).toList();
    final approved =
        allTickets.where((t) => t.adminApproved && !t.adminRejected).toList();
    final rejected =
        allTickets.where((t) => t.adminRejected).toList();

    List<SupportTicket> shown;
    switch (_filter) {
      case 1:
        shown = approved;
        break;
      case 2:
        shown = rejected;
        break;
      default:
        shown = waiting;
    }

    return Column(children: [
      // ── Filtros ──
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          _FilterBtn('Aguardando', waiting.length, AppTheme.warning,
              _filter == 0, () => setState(() => _filter = 0)),
          const SizedBox(width: 6),
          _FilterBtn('Aprovados', approved.length, AppTheme.success,
              _filter == 1, () => setState(() => _filter = 1)),
          const SizedBox(width: 6),
          _FilterBtn('Recusados', rejected.length, AppTheme.error,
              _filter == 2, () => setState(() => _filter = 2)),
        ]),
      ),
      const Divider(height: 1),

      // ── Lista ──
      shown.isEmpty
          ? Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isReturn
                          ? Icons.assignment_return_outlined
                          : Icons.assignment_outlined,
                      size: 56,
                      color: AppTheme.primary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _filter == 0
                          ? 'Nenhum chamado aguardando aprovação'
                          : _filter == 1
                              ? 'Nenhum chamado aprovado ainda'
                              : 'Nenhum chamado recusado',
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _TicketCard(
                  ticket: shown[i],
                  isAdmin: ds.isAdmin,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TicketDetailScreen(ticket: shown[i], isChat: false),
                    ),
                  ),
                ),
              ),
            ),
    ]);
  }
}

// ─── Botão de filtro ──────────────────────────────────────────────────────────

class _FilterBtn extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterBtn(
      this.label, this.count, this.color, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: selected ? Colors.white : color,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text('$count $label',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : color)),
          ]),
        ),
      );
}

// ignore: unused_element
class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$count $label',
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final bool isAdmin;
  final VoidCallback onTap;
  const _TicketCard(
      {required this.ticket,
      required this.isAdmin,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(ticket.status);
    final notApproved = !ticket.adminApproved && isAdmin;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notApproved
              ? AppTheme.error.withValues(alpha: 0.4)
              : AppTheme.divider,
          width: notApproved ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(ticket.subject,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (notApproved)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Aguarda aprovação',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(ticket.status.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 13, color: AppTheme.textHint),
              const SizedBox(width: 4),
              Text(ticket.clientName,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 12),
              const Icon(Icons.label_outline,
                  size: 13, color: AppTheme.textHint),
              const SizedBox(width: 4),
              Text(ticket.category.label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textHint)),
            ]),
            if (ticket.agentNotes != null &&
                ticket.agentNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  const Icon(Icons.notes, size: 13, color: AppTheme.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(ticket.agentNotes!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Color _statusColor(TicketStatus s) {
    switch (s) {
      case TicketStatus.open:
        return AppTheme.warning;
      case TicketStatus.inProgress:
        return AppTheme.info;
      case TicketStatus.pendingClient:
        return AppTheme.warning;
      case TicketStatus.resolved:
        return AppTheme.success;
      case TicketStatus.closed:
        return AppTheme.textHint;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ABA AVALIAÇÕES / MÉTRICAS POR ATENDENTE (só admin)
// ═════════════════════════════════════════════════════════════════════════════

class _AgentStatsTab extends StatefulWidget {
  const _AgentStatsTab();
  @override
  State<_AgentStatsTab> createState() => _AgentStatsTabState();
}

class _AgentStatsTabState extends State<_AgentStatsTab> {
  // Filtro de mês: 0 = mês atual, 1 = mês anterior, 2 = 2 meses atrás
  int _monthOffset = 0;

  DateTime get _selectedMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month - _monthOffset, 1);
  }

  String _monthLabel(int offset) {
    final dt = DateTime(DateTime.now().year, DateTime.now().month - offset, 1);
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${months[dt.month - 1]}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final stats = ds.getAgentStatsByMonth(_selectedMonth);

    return Column(children: [
      // ── Filtro de mês ──────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          const Icon(Icons.calendar_month, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          const Text('Mês:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _monthOffset = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _monthOffset == i ? AppTheme.primary : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _monthOffset == i ? AppTheme.primary : AppTheme.divider,
                  ),
                ),
                child: Text(
                  _monthLabel(i),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _monthOffset == i ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          )),
          const Spacer(),
          // Botão apagar histórico do mês selecionado
          TextButton.icon(
            onPressed: stats.isEmpty ? null : () => _confirmClearMonth(context, ds),
            icon: const Icon(Icons.delete_outline, size: 15),
            label: const Text('Limpar', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          ),
        ]),
      ),
      const Divider(height: 1),

      // ── Cabeçalho da tabela ────────────────────────────────────────
      Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Expanded(
            flex: 3,
            child: Text('Atendente',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          ),
          const Expanded(
            flex: 2,
            child: Text('Tempo médio',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          ),
          const Expanded(
            flex: 2,
            child: Text('Avaliação',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          ),
          const Expanded(
            flex: 2,
            child: Text('Atendimentos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          ),
        ]),
      ),
      const Divider(height: 1),

      // ── Lista de atendentes ────────────────────────────────────────
      if (stats.isEmpty)
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 56,
                    color: AppTheme.primary.withValues(alpha: 0.25)),
                const SizedBox(height: 12),
                Text('Nenhum atendimento em ${_monthLabel(_monthOffset)}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                const Text('As métricas aparecem conforme os atendimentos são realizados',
                    style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        )
      else
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(0),
            itemCount: stats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = stats[i];
              final name = s['agentName'] as String;
              final total = s['total'] as int;
              final avgMin = s['avgTimeMin'] as double;
              final avgRating = s['avgRating'] as double;
              final ratingCount = s['ratingCount'] as int;

              return Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  // Nome e cargo
                  Expanded(
                    flex: 3,
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                  // Tempo médio
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatMin(avgMin),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppTheme.info),
                    ),
                  ),
                  // Avaliação média
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (avgRating > 0) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(' ($ratingCount)',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textHint)),
                        ] else
                          const Text('-',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                  // Total de atendimentos no mês
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$total',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
    ]);
  }

  String _formatMin(double min) {
    if (min == 0) return '-';
    if (min < 60) return '${min.toInt()}min';
    final h = (min / 60).floor();
    final m = (min % 60).toInt();
    return m > 0 ? '${h}h${m}min' : '${h}h';
  }

  Future<void> _confirmClearMonth(BuildContext context, DataService ds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar histórico do mês?'),
        content: Text(
            'Remover todas as avaliações e métricas de ${_monthLabel(_monthOffset)}?\n\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ds.clearMonthStats(_selectedMonth);
      if (mounted) setState(() {});
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TELA DE DETALHE — Chat OU Chamado
// ═════════════════════════════════════════════════════════════════════════════

class TicketDetailScreen extends StatefulWidget {
  final SupportTicket ticket;
  final bool isChat;
  const TicketDetailScreen(
      {super.key, required this.ticket, required this.isChat});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _notesCtrl = TextEditingController();
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    final ticket = context.read<DataService>().allTickets.firstWhere(
        (t) => t.id == widget.ticket.id,
        orElse: () => widget.ticket);
    _notesCtrl.text = ticket.agentNotes ?? '';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  SupportTicket _ticket(DataService ds) => ds.allTickets.firstWhere(
        (t) => t.id == widget.ticket.id,
        orElse: () => widget.ticket,
      );

  Future<void> _sendMessage({
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && attachmentUrl == null) return;
    _msgCtrl.clear();
    final ds = context.read<DataService>();
    final user = ds.currentUser!;
    await ds.sendTicketMessage(
      ticketId: widget.ticket.id,
      senderId: user.id,
      senderName: user.name,
      senderRole: user.role,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
    );
    // Som de envio: somente quando staff responde ao cliente no chat
    if (ds.isStaff && widget.isChat) {
      SoundHelper.playSuccess();
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Encerrar atendimento (staff)
  Future<void> _closeChat(DataService ds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Encerrar atendimento?'),
        content: const Text(
            'O cliente receberá uma solicitação de avaliação. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ds.closeChat(widget.ticket.id);
      if (mounted) Navigator.pop(context);
    }
  }

  /// Salvar observações do funcionário
  Future<void> _saveNotes(DataService ds) async {
    await ds.updateTicketNotes(
        widget.ticket.id, _notesCtrl.text.trim());
    if (mounted) {
      setState(() => _showNotes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Observações salvas'),
            backgroundColor: AppTheme.success),
      );
    }
  }

  /// Aprovar chamado (admin)
  Future<void> _approveTicket(DataService ds) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aprovar chamado'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Adicione uma nota de aprovação (opcional):'),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ex: Aprovado. Entrar em contato com o cliente...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ds.approveTicket(widget.ticket.id,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() {});
    }
  }

  /// Recusar chamado (admin)
  Future<void> _rejectTicket(DataService ds) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recusar chamado'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Informe o motivo da recusa:'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ex: Documentação insuficiente, pedido não encontrado...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final reason = reasonCtrl.text.trim().isEmpty
          ? 'Chamado recusado pelo administrador.'
          : reasonCtrl.text.trim();
      await ds.rejectTicket(widget.ticket.id, reason: reason);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  /// Selecionar pedido pelo ID para enviar no chat (cliente)
  void _showQuickOrderPicker(DataService ds) {
    final clientOrders = ds.allOrders
        .where((o) =>
            o.clientId == (ds.currentUser?.clientId ?? ''))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Icon(Icons.receipt_long, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Selecionar pedido',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          if (clientOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhum pedido encontrado',
                  style: TextStyle(color: AppTheme.textHint)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: clientOrders.length,
                itemBuilder: (ctx, i) {
                  final order = clientOrders[i];
                  return ListTile(
                    leading: const Icon(Icons.receipt_outlined,
                        color: AppTheme.primary),
                    title: Text(order.invoiceNumber.isNotEmpty ? order.invoiceNumber : order.id,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${order.status.label} · ${order.items.length} item(s)'),
                    onTap: () async {
                      Navigator.pop(context);
                      final msg =
                          'Pedido: ${order.invoiceNumber.isNotEmpty ? order.invoiceNumber : order.id} (${order.status.label})';
                      final user = ds.currentUser!;
                      await ds.sendTicketMessage(
                        ticketId: widget.ticket.id,
                        senderId: user.id,
                        senderName: user.name,
                        senderRole: user.role,
                        text: msg,
                      );
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final ticket = _ticket(ds);
    final isStaff = ds.isStaff;
    final isAdmin = ds.isAdmin;
    final isAssignedToMe =
        ticket.assignedToUserId == ds.currentUser?.id;
    final isOpen = ticket.status == TicketStatus.open ||
        ticket.status == TicketStatus.inProgress;
    final canRate = !isStaff &&
        ticket.status == TicketStatus.resolved &&
        ticket.rating == null;
    // Ticket é "chamado" se foi criado por funcionário (campo definitivo)
    final isChamado = ticket.createdByStaff;
    // Exibe como chat somente se passou isChat=true E não é chamado interno
    final showAsChat = widget.isChat && !isChamado;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  showAsChat
                      ? ticket.clientName
                      : ticket.subject,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                  showAsChat
                      ? 'Chat com suporte'
                      : 'Chamado #${ticket.id.substring(0, 6)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white70)),
            ]),
        actions: [
          // ── Botão de notas (funcionário não-admin em qualquer ticket) ──
          if (isStaff)
            IconButton(
              icon: Icon(
                Icons.notes,
                color: _showNotes ? Colors.amber : Colors.white,
              ),
              tooltip: 'Observações internas',
              onPressed: () => setState(() => _showNotes = !_showNotes),
            ),
          // ── Menu de ações para CHAT (encerrar) ──────────────────────
          if (showAsChat && isStaff && isOpen)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) async {
                if (v == 'close') await _closeChat(ds);
              },
              itemBuilder: (_) => [
                if (isAssignedToMe || isAdmin)
                  const PopupMenuItem(
                      value: 'close',
                      child: Row(children: [
                        Icon(Icons.call_end, color: AppTheme.error, size: 18),
                        SizedBox(width: 8),
                        Text('Encerrar atendimento'),
                      ])),
              ],
            ),
          // ── Menu de ações para CHAMADO (admin: aprovar / recusar) ────
          if (!showAsChat && isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) async {
                switch (v) {
                  case 'approve':
                    await _approveTicket(ds);
                    break;
                  case 'reject':
                    await _rejectTicket(ds);
                    break;
                }
              },
              itemBuilder: (_) {
                final isPending =
                    !ticket.adminApproved && !ticket.adminRejected;
                return [
                  if (isPending)
                    const PopupMenuItem(
                        value: 'approve',
                        child: Row(children: [
                          Icon(Icons.check_circle,
                              color: AppTheme.success, size: 18),
                          SizedBox(width: 8),
                          Text('Aprovar chamado'),
                        ])),
                  if (isPending)
                    const PopupMenuItem(
                        value: 'reject',
                        child: Row(children: [
                          Icon(Icons.cancel, color: AppTheme.error, size: 18),
                          SizedBox(width: 8),
                          Text('Recusar chamado'),
                        ])),
                ];
              },
            ),
        ],
      ),
      body: showAsChat
          ? _buildChatBody(context, ds, ticket, isStaff, isAdmin,
              isAssignedToMe, isOpen, canRate)
          : _buildTicketBody(context, ds, ticket, isAdmin),
    );
  }

  // ─── BODY: CHAMADO (não chat) ─────────────────────────────────────────────

  Widget _buildTicketBody(BuildContext context, DataService ds,
      SupportTicket ticket, bool isAdmin) {
    final isPending = !ticket.adminApproved && !ticket.adminRejected;
    final isApproved = ticket.adminApproved;
    final isRejected = ticket.adminRejected;

    // Buscar pedido relacionado para NF clicável
    final relatedOrder = ticket.relatedOrderId != null
        ? ds.allOrders.where((o) => o.id == ticket.relatedOrderId).firstOrNull
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status badge ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPending
                  ? AppTheme.warning.withValues(alpha: 0.08)
                  : isApproved
                      ? AppTheme.success.withValues(alpha: 0.08)
                      : AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPending
                    ? AppTheme.warning.withValues(alpha: 0.3)
                    : isApproved
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : AppTheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(children: [
              Icon(
                isPending
                    ? Icons.hourglass_top
                    : isApproved
                        ? Icons.check_circle
                        : Icons.cancel,
                color: isPending
                    ? AppTheme.warning
                    : isApproved
                        ? AppTheme.success
                        : AppTheme.error,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending
                          ? 'Aguardando aprovação do Admin'
                          : isApproved
                              ? 'Chamado Aprovado'
                              : 'Chamado Recusado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isPending
                            ? AppTheme.warning
                            : isApproved
                                ? AppTheme.success
                                : AppTheme.error,
                      ),
                    ),
                    if (isApproved && ticket.adminApprovalNote != null &&
                        ticket.adminApprovalNote!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(ticket.adminApprovalNote!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                    if (isRejected && ticket.adminRejectionNote != null &&
                        ticket.adminRejectionNote!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Motivo: ${ticket.adminRejectionNote!}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Informações do chamado ──────────────────────────────────
          _InfoCard(children: [
            _InfoRow(Icons.person_outline, 'Cliente', ticket.clientName),
            _InfoRow(Icons.label_outline, 'Tipo', ticket.category.label),
            _InfoRow(Icons.flag_outlined, 'Prioridade', ticket.priority.label),
            _InfoRow(Icons.person_pin_outlined, 'Aberto por',
                ticket.createdByUserName),
            _InfoRow(Icons.calendar_today_outlined, 'Data',
                _formatDate(ticket.createdAt)),
            if (ticket.relatedOrderInvoice != null)
              _InfoRow(Icons.receipt_long_outlined, 'NF',
                  ticket.relatedOrderInvoice!),
            if (ticket.assignedToUserName != null)
              _InfoRow(Icons.support_agent, 'Atendente',
                  ticket.assignedToUserName!),
          ]),

          const SizedBox(height: 12),

          // ── Pedido relacionado (NF clicável) ───────────────────────
          if (relatedOrder != null || ticket.relatedOrderInvoice != null) ...[
            _SectionTitle('Pedido Relacionado'),
            GestureDetector(
              onTap: relatedOrder != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(orderId: relatedOrder.id),
                        ),
                      )
                  : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.receipt_long,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relatedOrder?.invoiceNumber ??
                              ticket.relatedOrderInvoice ??
                              '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primary),
                        ),
                        if (relatedOrder != null)
                          Text(
                              '${relatedOrder.status.label} · ${relatedOrder.items.length} item(s)',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (relatedOrder != null) ...[
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    const Text('Abrir',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Devolução: itens do pedido ──────────────────────────────
          if (ticket.category == TicketCategory.return_product &&
              relatedOrder != null) ...[
            _SectionTitle(
                'Itens para Devolução (${ticket.returnQuantity ?? 0} unid.)'),
            ...relatedOrder.items.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 18, color: AppTheme.textHint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('SKU: ${item.sku} · Qtd: ${item.quantity}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ]),
                )),
            const SizedBox(height: 12),
          ],

          // ── Observações do funcionário ─────────────────────────────
          if (ticket.agentNotes != null &&
              ticket.agentNotes!.isNotEmpty) ...[
            _SectionTitle('Observações do Atendente'),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.info.withValues(alpha: 0.25)),
              ),
              child: Text(ticket.agentNotes!,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 12),
          ],

          // ── Painel de observações internas (staff) ─────────────────
          if (_showNotes) ...[
            _SectionTitle('Observações Internas (visível só para staff)'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                TextField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Descreva detalhes, próximos passos, contatos realizados...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveNotes(ds),
                    icon: const Icon(Icons.save, size: 14),
                    label: const Text('Salvar'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.info,
                        foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // ── Painel de aprovação / recusa (admin, chamado pendente) ─
          if (isAdmin && isPending) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectTicket(ds),
                  icon: const Icon(Icons.cancel_outlined,
                      color: AppTheme.error, size: 18),
                  label: const Text('Recusar',
                      style: TextStyle(color: AppTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveTicket(ds),
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 18),
                  label: const Text('Aprovar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─── BODY: CHAT ───────────────────────────────────────────────────────────

  Widget _buildChatBody(
      BuildContext context,
      DataService ds,
      SupportTicket ticket,
      bool isStaff,
      bool isAdmin,
      bool isAssignedToMe,
      bool isOpen,
      bool canRate) {
    return Column(children: [
      _TicketInfoBar(ticket: ticket, isAdmin: isAdmin),

      if (_showNotes)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.notes, color: AppTheme.info, size: 16),
              SizedBox(width: 6),
              Text('Observações internas (visível só para staff)',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.info,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descreva detalhes, próximos passos...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _saveNotes(ds),
                icon: const Icon(Icons.save, size: 14),
                label: const Text('Salvar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.info,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ]),
        ),

      Expanded(
        child: ticket.messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 52,
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('Nenhuma mensagem ainda',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: ticket.messages.length,
                itemBuilder: (context, i) {
                  final msg = ticket.messages[i];
                  final isMine = msg.senderId == ds.currentUser?.id;
                  return _MessageBubble(message: msg, isMine: isMine);
                },
              ),
      ),

      if (canRate) _RatingBar(ticket: ticket),

      if (isOpen &&
          (isStaff || !isStaff && ticket.status != TicketStatus.resolved))
        _ChatInput(
          controller: _msgCtrl,
          onSend: _sendMessage,
          isStaff: isStaff,
          onQuickOrder: (!isStaff && widget.isChat)
              ? () => _showQuickOrderPicker(ds)
              : null,
        )
      else if (!isOpen && !canRate)
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline,
                size: 15, color: AppTheme.textHint),
            const SizedBox(width: 6),
            Text(
              ticket.status == TicketStatus.resolved
                  ? 'Atendimento encerrado'
                  : 'Encerrado',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textHint),
            ),
          ]),
        ),
    ]);
  }
}

// ─── Widgets auxiliares para chamado ─────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3)),
      );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: children
              .asMap()
              .entries
              .map((e) => Column(children: [
                    e.value,
                    if (e.key < children.length - 1)
                      const Divider(height: 16),
                  ]))
              .toList(),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppTheme.textHint),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ]);
}

// ─── Info bar do ticket ───────────────────────────────────────────────────────

class _TicketInfoBar extends StatelessWidget {
  final SupportTicket ticket;
  final bool isAdmin;
  const _TicketInfoBar({required this.ticket, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isOpen = ticket.status == TicketStatus.open ||
        ticket.status == TicketStatus.inProgress;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOpen ? AppTheme.success : AppTheme.textHint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ticket.assignedToUserName != null
                ? 'Atendente: ${ticket.assignedToUserName}'
                : isOpen
                    ? 'Aguardando atendente'
                    : 'Encerrado',
            style: TextStyle(
              fontSize: 12,
              color: isOpen ? AppTheme.success : AppTheme.textHint,
            ),
          ),
        ),
        if (isAdmin && ticket.adminApproved)
          const Icon(Icons.verified, size: 16, color: AppTheme.success),
        if (isAdmin && !ticket.adminApproved)
          const Icon(Icons.pending, size: 16, color: AppTheme.warning),
      ]),
    );
  }
}

// ─── Bolha de mensagem ────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final TicketMessage message;
  final bool isMine;
  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
        ),
        child: Text(message.text,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.info),
            textAlign: TextAlign.center),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMine ? 48 : 0,
          right: isMine ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? AppTheme.primary
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4)
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(message.senderName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary)),
            const SizedBox(height: 2),
            // Anexo de imagem
            if (message.attachmentType == 'image' && message.attachmentUrl != null) ...
              [
                GestureDetector(
                  onTap: () => _showImageFull(context, message.attachmentUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: message.attachmentUrl!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(message.attachmentUrl!.split(',').last),
                            width: 180, height: 140, fit: BoxFit.cover,
                          )
                        : Image.network(
                            message.attachmentUrl!,
                            width: 180, height: 140, fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            // Anexo de arquivo
            if (message.attachmentType == 'file' && message.attachmentUrl != null) ...
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.white.withValues(alpha: 0.15) : AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file_outlined,
                          color: isMine ? Colors.white70 : AppTheme.primary, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          message.attachmentName ?? 'Arquivo',
                          style: TextStyle(
                              fontSize: 12,
                              color: isMine ? Colors.white : AppTheme.primary,
                              decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            if (message.text.isNotEmpty)
              Text(message.text,
                  style: TextStyle(
                      fontSize: 13,
                      color: isMine ? Colors.white : AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.sentAt),
              style: TextStyle(
                  fontSize: 10,
                  color: isMine
                      ? Colors.white70
                      : AppTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFull(BuildContext context, String src) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: src.startsWith('data:image')
                  ? Image.memory(base64Decode(src.split(',').last))
                  : Image.network(src),
            ),
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Input de mensagem ────────────────────────────────────────────────────────

typedef SendMessageCallback = Future<void> Function({
  String? attachmentUrl,
  String? attachmentName,
  String? attachmentType,
});

class _ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final SendMessageCallback onSend;
  final VoidCallback? onQuickOrder;
  final bool isStaff;
  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.isStaff,
    this.onQuickOrder,
  });

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  bool _pickingFile = false;

  Future<void> _pickAttachment() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      final ext = (file.extension ?? '').toLowerCase();
      final isImg = ['jpg','jpeg','png','gif','webp','bmp'].contains(ext);
      final mime = isImg
          ? (ext == 'png' ? 'image/png' : ext == 'gif' ? 'image/gif' : 'image/jpeg')
          : 'application/octet-stream';
      final b64 = base64Encode(file.bytes!);
      final dataUrl = 'data:$mime;base64,$b64';
      await widget.onSend(
        attachmentUrl: dataUrl,
        attachmentName: file.name,
        attachmentType: isImg ? 'image' : 'file',
      );
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Botão pedido rápido (clientes)
          if (widget.onQuickOrder != null) ...[
            Tooltip(
              message: 'Enviar pedido',
              child: Material(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: widget.onQuickOrder,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.bolt, color: AppTheme.primary, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          // Botão de anexo (só staff)
          if (widget.isStaff) ...[
            Tooltip(
              message: 'Anexar arquivo ou imagem',
              child: Material(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _pickingFile ? null : _pickAttachment,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _pickingFile
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file, color: AppTheme.primary, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Digite uma mensagem...',
                hintStyle: const TextStyle(color: AppTheme.textHint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                filled: true,
                fillColor: AppTheme.surface,
              ),
              onSubmitted: (_) => widget.onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => widget.onSend(),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Avaliação (cliente) ──────────────────────────────────────────────────────

class _RatingBar extends StatefulWidget {
  final SupportTicket ticket;
  const _RatingBar({required this.ticket});

  @override
  State<_RatingBar> createState() => _RatingBarState();
}

class _RatingBarState extends State<_RatingBar> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Como foi o atendimento?',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: () => setState(() => _selected = i + 1),
              child: Icon(
                _selected > i ? Icons.star : Icons.star_outline,
                color: Colors.amber,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _selected == 0
              ? null
              : () async {
                  await ds.rateTicket(widget.ticket.id, _selected);
                  if (context.mounted) setState(() {});
                },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Enviar avaliação'),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHEET — Novo Chamado (staff abre)
// ═════════════════════════════════════════════════════════════════════════════

class _NewTicketSheet extends StatefulWidget {
  final DataService ds;
  const _NewTicketSheet({required this.ds});

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _subjectCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _nfCtrl = TextEditingController(); // NF digitada manualmente
  TicketCategory _category = TicketCategory.complaint;
  TicketPriority _priority = TicketPriority.normal;
  String? _clientId;
  int _returnQty = 1;
  bool _saving = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _notesCtrl.dispose();
    _nfCtrl.dispose();
    super.dispose();
  }

  bool get _isReturn => _category == TicketCategory.return_product;

  Future<void> _save() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o assunto do chamado.')));
      return;
    }
    if (_notesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Preencha as observações do chamado.')));
      return;
    }
    final ds = widget.ds;
    if (ds.clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nenhum cliente cadastrado.')));
      return;
    }
    setState(() => _saving = true);

    final selectedClient = _clientId != null
        ? ds.clients.firstWhere((c) => c.id == _clientId,
            orElse: () => ds.clients.first)
        : ds.clients.first;

    // NF digitada manualmente
    final nfDigitada = _nfCtrl.text.trim().isEmpty ? null : _nfCtrl.text.trim();

    final ticket = await ds.createTicket(
      clientId: selectedClient.id,
      clientName: selectedClient.companyName,
      createdByUserId: ds.currentUser!.id,
      createdByUserName: ds.currentUser!.name,
      category: _category,
      subject: _subjectCtrl.text.trim(),
      relatedOrderId: null,
      relatedOrderInvoice: nfDigitada,
      isReturnRequest: _isReturn,
      createdByStaff: true,
    );

    // Salvar observações e dados de devolução
    if (_notesCtrl.text.trim().isNotEmpty) {
      await ds.updateTicketNotes(ticket.id, _notesCtrl.text.trim());
    }
    if (_isReturn && _returnQty > 0) {
      await ds.updateTicketReturnData(ticket.id, _returnQty, nfDigitada);
    }

    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.ds;
    _clientId ??=
        ds.clients.isNotEmpty ? ds.clients.first.id : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header
          Row(children: [
            const Icon(Icons.assignment_add,
                color: AppTheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Novo Chamado',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),

          // Assunto
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Assunto *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Categoria e Prioridade
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<TicketCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                    labelText: 'Tipo', border: OutlineInputBorder()),
                items: [
                  TicketCategory.complaint,
                  TicketCategory.damage,
                  TicketCategory.shipping,
                  TicketCategory.billing,
                  TicketCategory.return_product,
                  TicketCategory.technical,
                  TicketCategory.stock,
                  TicketCategory.other,
                ]
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label,
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _category = v!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<TicketPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    border: OutlineInputBorder()),
                items: TicketPriority.values
                    .map((p) => DropdownMenuItem(
                        value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _priority = v!),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Cliente
          if (ds.clients.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _clientId,
              decoration: const InputDecoration(
                  labelText: 'Cliente',
                  border: OutlineInputBorder()),
              items: ds.clients
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.companyName,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _clientId = v;
              }),
            ),
          const SizedBox(height: 12),

          // DEVOLUÇÃO: NF + quantidade
          if (_isReturn) ...[
            TextField(
              controller: _nfCtrl,
              decoration: const InputDecoration(
                labelText: 'Número da NF (opcional)',
                prefixIcon: Icon(Icons.receipt_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            // Quantidade de itens
            Row(children: [
              const Text('Quantidade de itens:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  if (_returnQty > 1) {
                    setState(() => _returnQty--);
                  }
                },
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.primary),
              ),
              Text('$_returnQty',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => setState(() => _returnQty++),
                icon: const Icon(Icons.add_circle_outline,
                    color: AppTheme.primary),
              ),
            ]),
            const SizedBox(height: 4),
          ],

          // NF para chamados não-devolução
          if (!_isReturn) ...[
            TextField(
              controller: _nfCtrl,
              decoration: const InputDecoration(
                labelText: 'Número da NF (opcional)',
                prefixIcon: Icon(Icons.receipt_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
          ],


          // Observações livres (OBRIGATÓRIO para o funcionário descrever o chamado)
          const Text('Observações *',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Descreva o que aconteceu, detalhes do problema...',
              hintStyle:
                  const TextStyle(color: AppTheme.textHint),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),

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
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Text('Criar Chamado'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHEET — Configurações de Horário de Atendimento
// ═════════════════════════════════════════════════════════════════════════════

class _SupportSettingsSheet extends StatefulWidget {
  final DataService ds;
  const _SupportSettingsSheet({required this.ds});

  @override
  State<_SupportSettingsSheet> createState() =>
      _SupportSettingsSheetState();
}

class _SupportSettingsSheetState
    extends State<_SupportSettingsSheet> {
  late int _startH, _startM, _endH, _endM;
  late List<int> _workDays;
  final _waitMsgCtrl = TextEditingController();
  final _offlineMsgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = widget.ds.supportSettings;
    _startH = s.startHour;
    _startM = s.startMinute;
    _endH = s.endHour;
    _endM = s.endMinute;
    _workDays = List.from(s.workDays);
    _waitMsgCtrl.text = s.waitMessage;
    _offlineMsgCtrl.text = s.offlineMessage;
  }

  @override
  void dispose() {
    _waitMsgCtrl.dispose();
    _offlineMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = widget.ds.supportSettings;
    // NÃO altera isOnline aqui — toggle fica no botão do admin no header
    s.startHour = _startH;
    s.startMinute = _startM;
    s.endHour = _endH;
    s.endMinute = _endM;
    s.workDays = _workDays;
    s.waitMessage = _waitMsgCtrl.text;
    s.offlineMessage = _offlineMsgCtrl.text;
    await widget.ds.updateSupportSettings(s);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            const Icon(Icons.schedule, color: AppTheme.primary),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('Horário de Atendimento',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16))),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),

          // Dias da semana
          const Text('Dias de atendimento',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final dayNum = i + 1;
              final selected = _workDays.contains(dayNum);
              return FilterChip(
                label: Text(days[i]),
                selected: selected,
                onSelected: (v) => setState(() => v
                    ? _workDays.add(dayNum)
                    : _workDays.remove(dayNum)),
                selectedColor:
                    AppTheme.primary.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primary,
              );
            }),
          ),
          const SizedBox(height: 16),

          // Horário início/fim
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Início',
                        style:
                            TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _TimePicker(
                      hour: _startH,
                      minute: _startM,
                      onChanged: (h, m) =>
                          setState(() {
                        _startH = h;
                        _startM = m;
                      }),
                    ),
                  ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fim',
                        style:
                            TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _TimePicker(
                      hour: _endH,
                      minute: _endM,
                      onChanged: (h, m) =>
                          setState(() {
                        _endH = h;
                        _endM = m;
                      }),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),

          // Mensagem de espera
          const Text('Mensagem de espera',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _waitMsgCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),

          // Mensagem offline
          const Text('Mensagem fora do horário',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _offlineMsgCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Salvar Configurações'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final int hour;
  final int minute;
  final void Function(int h, int m) onChanged;
  const _TimePicker(
      {required this.hour,
      required this.minute,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (picked != null) {
          onChanged(picked.hour, picked.minute);
        }
      },
      icon: const Icon(Icons.access_time, size: 16),
      label: Text(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
