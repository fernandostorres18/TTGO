// lib/core/widgets/common_widgets.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../models/app_models.dart';

final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numberFormat = NumberFormat('#,##0', 'pt_BR');

String formatCurrency(double value) => _currencyFormat.format(value);
String formatNumber(int value) => _numberFormat.format(value);
String formatDate(DateTime d) => DateFormat('dd/MM/yyyy', 'pt_BR').format(d);
String formatDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(d);

// ─── METRIC CARD ──────────────────────────────────────────────────────────

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color? bgColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.bgColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textHint),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── STATUS BADGE ─────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;

  const StatusBadge({super.key, required this.label, required this.color, this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

Color orderStatusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.recebido: return AppTheme.statusRecebido;
    case OrderStatus.aguardandoSeparacao: return AppTheme.statusAguardando;
    case OrderStatus.separando: return AppTheme.statusSeparando;
    case OrderStatus.faturado: return AppTheme.statusFaturado;
    case OrderStatus.enviado: return AppTheme.statusEnviado;
    case OrderStatus.finalizado: return AppTheme.statusFinalizado;
  }
}

Widget orderStatusBadge(OrderStatus s) =>
    StatusBadge(label: s.label, color: orderStatusColor(s));

Color orderSizeColor(OrderSize s) {
  switch (s) {
    case OrderSize.pequeno: return Colors.teal;
    case OrderSize.medio: return Colors.orange;
    case OrderSize.grande: return Colors.deepPurple;
    case OrderSize.envelope: return Colors.indigo;
  }
}

Widget orderSizeBadge(OrderSize s) =>
    StatusBadge(label: s.label, color: orderSizeColor(s));

// ─── SECTION HEADER ───────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
          ],
          Text(title, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary,
          )),
          const Spacer(),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 13, color: AppTheme.primary)),
            ),
        ],
      ),
    );
  }
}

// ─── GRADIENT HEADER ──────────────────────────────────────────────────────

class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget>? actions;
  final bool showBack;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.actions,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.headerGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                )
              else
                const Icon(Icons.warehouse, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                    )),
                    if (subtitle != null)
                      Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── EMPTY STATE ──────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, size: 48, color: AppTheme.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── INFO ROW ─────────────────────────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  const InfoRow({super.key, required this.label, required this.value, this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ─── ORDER STATUS STEPPER ─────────────────────────────────────────────────

class OrderStatusStepper extends StatelessWidget {
  final OrderStatus currentStatus;

  const OrderStatusStepper({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final statuses = OrderStatus.values;
    final currentIdx = statuses.indexOf(currentStatus);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(statuses.length, (i) {
          final s = statuses[i];
          final isCompleted = i < currentIdx;
          final isCurrent = i == currentIdx;
          final color = orderStatusColor(s);

          return Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent ? color : AppTheme.divider,
                      shape: BoxShape.circle,
                      border: isCurrent ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : Icons.circle,
                      size: 14,
                      color: isCompleted || isCurrent ? Colors.white : AppTheme.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(s.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: isCurrent ? color : isCompleted ? AppTheme.textSecondary : AppTheme.textHint,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (i < statuses.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  color: i < currentIdx ? AppTheme.success : AppTheme.divider,
                  margin: const EdgeInsets.only(bottom: 16),
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── CLIENT AVATAR ────────────────────────────────────────────────────────

const _clientColors = [
  Color(0xFF2E7D32), Color(0xFF1565C0), Color(0xFF6A1B9A),
  Color(0xFFE65100), Color(0xFF00695C), Color(0xFFC62828),
];

class ClientAvatar extends StatelessWidget {
  final String initials;
  final int colorIndex;
  final double size;
  final String? photoUrl; // URL da foto do cliente

  const ClientAvatar({
    super.key,
    required this.initials,
    required this.colorIndex,
    this.size = 40,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = _clientColors[colorIndex % _clientColors.length];

    // Se tem foto, mostra a imagem com fallback para iniciais
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      // Suporta base64 (seleção local) e URL remota
      if (photoUrl!.startsWith('data:image')) {
        final b64 = photoUrl!.split(',').last;
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 4),
          child: Image.memory(
            base64Decode(b64),
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsWidget(color),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget(color),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _initialsWidget(color),
        ),
      );
    }

    return _initialsWidget(color);
  }

  Widget _initialsWidget(Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size / 4),
    ),
    child: Center(
      child: Text(initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.35),
      ),
    ),
  );
}

// ─── LOADING OVERLAY ──────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({super.key, required this.isLoading, required this.child, this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black26,
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primary),
                      if (message != null) ...[
                        const SizedBox(height: 12),
                        Text(message!, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── BARCODE FIELD (simulated scanner) ───────────────────────────────────

class BarcodeInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onSubmit;
  final bool autofocus;

  const BarcodeInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onSubmit,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    decoration: InputDecoration(
                      hintText: hint,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.check, size: 20, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
