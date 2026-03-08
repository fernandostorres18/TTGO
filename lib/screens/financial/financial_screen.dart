// lib/screens/financial/financial_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});
  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  // Only month selection — generates last 12 months from today
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _selectedMonth = DateTime.now().month;
  }

  // Generate last 12 months, limited by client registration date
  List<DateTime> _availableMonths(DataService ds) {
    final now = DateTime.now();
    DateTime earliest = now.subtract(const Duration(days: 365));

    // If client, limit to their registration date
    if (ds.isClient && ds.currentClientId != null) {
      final client = ds.getClient(ds.currentClientId!);
      if (client != null && client.createdAt.isAfter(earliest)) {
        earliest = DateTime(client.createdAt.year, client.createdAt.month, 1);
      }
    }

    final months = <DateTime>[];
    var d = DateTime(now.year, now.month, 1);
    while (!d.isBefore(earliest) && months.length < 12) {
      months.add(d);
      d = DateTime(d.year, d.month - 1, 1);
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final isClient = ds.isClient;
    final clientId = ds.currentClientId;

    // Block operator (não bloqueia support agent — acesso somente leitura)
    if (ds.isOperator) {
      return Scaffold(
        body: Column(
          children: [
            const GradientHeader(title: 'Financeiro', subtitle: 'Acesso restrito', showBack: true),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 64, color: AppTheme.error.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    const Text('Acesso não autorizado',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('Operadores não têm acesso ao módulo financeiro.',
                        style: TextStyle(color: AppTheme.textHint), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final targetClients = isClient
      ? [ds.getClient(clientId!)].where((c) => c != null).cast<Client>().toList()
      : ds.activeClients;

    final availableMonths = _availableMonths(ds);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          GradientHeader(
            title: isClient ? 'Meu Faturamento' : 'Financeiro',
            subtitle: 'Relatórios e cobranças mensais',
            showBack: true,
          ),
          // Month selector only (no year dropdown)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: availableMonths.length,
                itemBuilder: (ctx, i) {
                  final month = availableMonths[i];
                  final isSelected = month.year == _selectedYear && month.month == _selectedMonth;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedYear = month.year;
                      _selectedMonth = month.month;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.divider),
                      ),
                      child: Text(
                        '${_monthLabel(month.month)}/${month.year}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(context, ds, targetClients),
                const SizedBox(height: 16),
                _buildRevenueChart(context, ds, targetClients),
                const SizedBox(height: 16),
                ...targetClients.map((client) => _ClientBillingCard(
                  client: client,
                  ds: ds,
                  year: _selectedYear,
                  month: _selectedMonth,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DataService ds, List<Client> clients) {
    double totalRevenue = 0;
    int totalOrders = 0;

    for (final client in clients) {
      final billing = ds.getBillingForClient(client.id, _selectedYear, _selectedMonth);
      if (billing != null) {
        totalRevenue += billing.finalValue;
        totalOrders += billing.totalOrders;
      } else {
        final orders = ds.getOrdersByClient(client.id).where((o) =>
          o.createdAt.year == _selectedYear && o.createdAt.month == _selectedMonth &&
          o.status != OrderStatus.recebido).toList();
        totalRevenue += orders.fold(0.0, (s, o) => s + o.orderValue);
        totalOrders += orders.length;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Resumo — ${_monthLabel(_selectedMonth)}/$_selectedYear',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(formatCurrency(totalRevenue),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const Text('Faturamento Total', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _whiteStat('Total Pedidos', '$totalOrders')),
              const SizedBox(width: 10),
              Expanded(child: _whiteStat('Clientes Ativos', '${clients.length}')),
              const SizedBox(width: 10),
              Expanded(child: _whiteStat('Ticket Médio', totalOrders > 0 ? formatCurrency(totalRevenue / totalOrders) : 'R\$0')),
            ],
          ),
        ],
      ),
    );
  }

  String _monthLabel(int m) {
    const months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return months[m - 1];
  }

  Widget _whiteStat(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
    child: Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9), textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _buildRevenueChart(BuildContext context, DataService ds, List<Client> clients) {
    final last6Months = List.generate(6, (i) {
      final d = DateTime(_selectedYear, _selectedMonth - i, 1);
      return d;
    }).reversed.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Faturamento — Últimos 6 Meses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 5000,
                barGroups: last6Months.asMap().entries.map((e) {
                  final total = clients.fold(0.0, (s, c) {
                    final orders = ds.getOrdersByClient(c.id).where((o) =>
                      o.createdAt.year == e.value.year && o.createdAt.month == e.value.month).toList();
                    return s + orders.fold(0.0, (s2, o) => s2 + o.orderValue);
                  });
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(
                      toY: total > 0 ? total : (50 + e.key * 200).toDouble(),
                      color: e.value.month == _selectedMonth ? AppTheme.primary : AppTheme.primaryLight.withValues(alpha: 0.6),
                      width: 28,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    )],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final d = last6Months[val.toInt()];
                        return Text(_monthLabel(d.month), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.divider, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CLIENT BILLING CARD ──────────────────────────────────────────────────

class _ClientBillingCard extends StatefulWidget {
  final Client client;
  final DataService ds;
  final int year;
  final int month;

  const _ClientBillingCard({required this.client, required this.ds, required this.year, required this.month});

  @override
  State<_ClientBillingCard> createState() => _ClientBillingCardState();
}

class _ClientBillingCardState extends State<_ClientBillingCard> {
  bool _loading = false;
  MonthlyBilling? _billing;

  @override
  void initState() {
    super.initState();
    _loadBilling();
  }

  @override
  void didUpdateWidget(covariant _ClientBillingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      _loadBilling();
    }
  }

  Future<void> _loadBilling() async {
    setState(() => _loading = true);
    final b = await widget.ds.calculateMonthlyBilling(widget.client.id, widget.year, widget.month);
    if (mounted) setState(() { _billing = b; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
    final billing = _billing;
    if (billing == null) return const SizedBox.shrink();

    final meetsMinimum = billing.calculatedValue >= billing.minimumMonthly;
    final extras = widget.ds.getBillingExtras(widget.client.id, widget.year, widget.month);
    final extraTotal = extras.fold(0.0, (s, e) => s + e.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: ClientAvatar(initials: widget.client.initials, colorIndex: widget.ds.clients.indexOf(widget.client)),
        title: Text(widget.client.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Row(
          children: [
            Text(formatCurrency(billing.finalValue + extraTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const SizedBox(width: 8),
            if (!meetsMinimum) const StatusBadge(label: 'MÍNIMO APLICADO', color: AppTheme.warning),
            if (meetsMinimum) const StatusBadge(label: 'ACIMA DO MÍNIMO', color: AppTheme.success),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(),
                Row(
                  children: [
                    _orderTypeStat('Pequenos', billing.smallOrders, formatCurrency(widget.client.priceSmallOrder), Colors.teal),
                    const SizedBox(width: 8),
                    _orderTypeStat('Médios', billing.mediumOrders, formatCurrency(widget.client.priceMediumOrder), Colors.orange),
                    const SizedBox(width: 8),
                    _orderTypeStat('Grandes', billing.largeOrders, formatCurrency(widget.client.priceLargeOrder), Colors.deepPurple),
                    const SizedBox(width: 8),
                    _orderTypeStat('Envelopes', billing.envelopeOrders, formatCurrency(widget.client.priceEnvelopeOrder), Colors.indigo),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _calcRow('Subtotal calculado', formatCurrency(billing.calculatedValue)),
                      _calcRow('Mínimo contratual', formatCurrency(billing.minimumMonthly)),
                      if (!meetsMinimum)
                        _calcRow('Acréscimo mínimo', formatCurrency(billing.finalValue - billing.calculatedValue), color: AppTheme.warning),
                      // Extras/discounts
                      if (extras.isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider()),
                        for (final e in extras)
                          _calcRow(
                            e.description,
                            (e.value >= 0 ? '+' : '') + formatCurrency(e.value),
                            color: e.isDiscount ? AppTheme.error : AppTheme.success,
                          ),
                      ],
                      const Divider(),
                      _calcRow('TOTAL A COBRAR', formatCurrency(billing.finalValue + extraTotal), bold: true, color: AppTheme.primary),
                    ],
                  ),
                ),
                // Add extra / discount buttons (admin only, not support agent)
                if (widget.ds.isAdmin && !widget.ds.isSupportAgent) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.success),
                          label: const Text('Adicionar Valor', style: TextStyle(fontSize: 12, color: AppTheme.success)),
                          onPressed: () => _showExtraDialog(context, isDiscount: false),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.success)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.error),
                          label: const Text('Aplicar Desconto', style: TextStyle(fontSize: 12, color: AppTheme.error)),
                          onPressed: () => _showExtraDialog(context, isDiscount: true),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                        ),
                      ),
                    ],
                  ),
                  if (extras.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit_note, size: 16, color: AppTheme.textSecondary),
                        label: const Text('Gerenciar extras', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        onPressed: () => _showExtrasManager(context),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Exportar PDF'),
                        onPressed: () => _exportPdf(context, billing, extras),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart, size: 16),
                        label: const Text('Exportar CSV'),
                        onPressed: () => _exportCsv(context, billing, extras),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExtraDialog(BuildContext context, {required bool isDiscount}) {
    final descCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDiscount ? 'Aplicar Desconto' : 'Adicionar Valor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: isDiscount ? 'Motivo do desconto' : 'Descrição do valor',
                prefixIcon: const Icon(Icons.description),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixIcon: Icon(Icons.attach_money),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isDiscount ? AppTheme.error : AppTheme.success),
            onPressed: () async {
              final desc = descCtrl.text.trim();
              final val = double.tryParse(valCtrl.text.trim());
              if (desc.isEmpty || val == null || val <= 0) return;
              final extra = BillingExtra(
                id: widget.ds.newBillingExtraId(),
                clientId: widget.client.id,
                year: widget.year,
                month: widget.month,
                description: desc,
                value: isDiscount ? -val : val,
                createdByUserId: widget.ds.currentUser!.id,
                createdAt: DateTime.now(),
              );
              await widget.ds.addBillingExtra(extra);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExtrasManager(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            final extras = widget.ds.getBillingExtras(widget.client.id, widget.year, widget.month);
            return AlertDialog(
              title: const Text('Extras e Descontos'),
              content: SizedBox(
                width: 320,
                child: extras.isEmpty
                    ? const Text('Nenhum extra/desconto adicionado.')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: extras.map((e) => ListTile(
                          dense: true,
                          leading: Icon(
                            e.isDiscount ? Icons.remove_circle : Icons.add_circle,
                            color: e.isDiscount ? AppTheme.error : AppTheme.success,
                            size: 20,
                          ),
                          title: Text(e.description, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            (e.value >= 0 ? '+' : '') + formatCurrency(e.value),
                            style: TextStyle(
                              color: e.isDiscount ? AppTheme.error : AppTheme.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.error, size: 18),
                            onPressed: () async {
                              await widget.ds.deleteBillingExtra(e.id);
                              setS(() {});
                              setState(() {});
                            },
                          ),
                        )).toList(),
                      ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
              ],
            );
          },
        );
      },
    );
  }

  // ── nomes dos meses ────────────────────────────────────────────────────────
  static const _months = ['Janeiro','Fevereiro','Março','Abril','Maio',
    'Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

  // ── PDF ────────────────────────────────────────────────────────────────────
  Future<void> _exportPdf(BuildContext context, MonthlyBilling billing, List<BillingExtra> extras) async {
    final mes = '${_months[billing.month - 1]} ${billing.year}';
    final meetsMin = billing.calculatedValue >= billing.minimumMonthly;
    final extraTotal = extras.fold(0.0, (s, e) => s + e.value);
    final totalFinal = billing.finalValue + extraTotal;

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('7B1FA2'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RELATÓRIO DE FATURAMENTO',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(mes, style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Cliente', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Text(billing.clientName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('Pedidos por Tipo', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [_pdfCell('Tipo', bold: true), _pdfCell('Qtd', bold: true), _pdfCell('Preço Unit.', bold: true), _pdfCell('Subtotal', bold: true)],
                ),
                pw.TableRow(children: [_pdfCell('Caixa Pequena'), _pdfCell('${billing.smallOrders}'), _pdfCell(formatCurrency(widget.client.priceSmallOrder)), _pdfCell(formatCurrency(billing.smallOrders * widget.client.priceSmallOrder))]),
                pw.TableRow(children: [_pdfCell('Caixa Média'), _pdfCell('${billing.mediumOrders}'), _pdfCell(formatCurrency(widget.client.priceMediumOrder)), _pdfCell(formatCurrency(billing.mediumOrders * widget.client.priceMediumOrder))]),
                pw.TableRow(children: [_pdfCell('Caixa Grande'), _pdfCell('${billing.largeOrders}'), _pdfCell(formatCurrency(widget.client.priceLargeOrder)), _pdfCell(formatCurrency(billing.largeOrders * widget.client.priceLargeOrder))]),
                pw.TableRow(children: [_pdfCell('Envelope'), _pdfCell('${billing.envelopeOrders}'), _pdfCell(formatCurrency(widget.client.priceEnvelopeOrder)), _pdfCell(formatCurrency(billing.envelopeOrders * widget.client.priceEnvelopeOrder))]),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('Resumo Financeiro', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _pdfRow('Subtotal calculado', formatCurrency(billing.calculatedValue)),
            _pdfRow('Mínimo contratual', formatCurrency(billing.minimumMonthly)),
            if (!meetsMin) _pdfRow('Acréscimo mínimo', formatCurrency(billing.finalValue - billing.calculatedValue), highlight: true),
            if (extras.isNotEmpty) ...[
              pw.Divider(color: PdfColors.grey300),
              for (final e in extras)
                _pdfRow(e.description, (e.value >= 0 ? '+' : '') + formatCurrency(e.value),
                    highlight: e.isDiscount),
            ],
            pw.Divider(color: PdfColors.grey400),
            _pdfRow('TOTAL A COBRAR', formatCurrency(totalFinal), bold: true),
            pw.SizedBox(height: 24),
            pw.Text(
              'Gerado em ${DateTime.now().day.toString().padLeft(2,'0')}/'
              '${DateTime.now().month.toString().padLeft(2,'0')}/'
              '${DateTime.now().year} — Fulfillment Master',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        );
      },
    ));

    final Uint8List bytes = await doc.save();
    final filename = 'faturamento_${billing.clientName.replaceAll(' ', '_')}_'
        '${billing.month.toString().padLeft(2,'0')}_${billing.year}.pdf';

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF "$filename" baixado!'), backgroundColor: AppTheme.success));
      }
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);
    }
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );

  pw.Widget _pdfRow(String label, String value, {bool bold = false, bool highlight = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: highlight ? PdfColors.orange700 : PdfColors.black)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: bold ? PdfColor.fromHex('7B1FA2') : highlight ? PdfColors.orange700 : PdfColors.black)),
        ],
      ),
    );

  // ── CSV ────────────────────────────────────────────────────────────────────
  void _exportCsv(BuildContext context, MonthlyBilling billing, List<BillingExtra> extras) {
    final mes = '${_months[billing.month - 1]} ${billing.year}';
    final extraTotal = extras.fold(0.0, (s, e) => s + e.value);
    final rows = <List<dynamic>>[
      ['RELATÓRIO DE FATURAMENTO — $mes'],
      [],
      ['Cliente', billing.clientName],
      [],
      ['Tipo', 'Quantidade', 'Preço Unitário (R\$)', 'Subtotal (R\$)'],
      ['Caixa Pequena', billing.smallOrders, widget.client.priceSmallOrder, billing.smallOrders * widget.client.priceSmallOrder],
      ['Caixa Média', billing.mediumOrders, widget.client.priceMediumOrder, billing.mediumOrders * widget.client.priceMediumOrder],
      ['Caixa Grande', billing.largeOrders, widget.client.priceLargeOrder, billing.largeOrders * widget.client.priceLargeOrder],
      ['Envelope', billing.envelopeOrders, widget.client.priceEnvelopeOrder, billing.envelopeOrders * widget.client.priceEnvelopeOrder],
      [],
      ['Subtotal calculado', '', '', billing.calculatedValue],
      ['Mínimo contratual', '', '', billing.minimumMonthly],
      if (billing.calculatedValue < billing.minimumMonthly) ['Acréscimo mínimo', '', '', billing.finalValue - billing.calculatedValue],
      if (extras.isNotEmpty) ...[
        [],
        ['Extras / Descontos', '', '', ''],
        for (final e in extras) [e.description, '', '', e.value],
      ],
      [],
      ['TOTAL A COBRAR', '', '', billing.finalValue + extraTotal],
      [],
      ['Gerado em', '${DateTime.now().day.toString().padLeft(2,'0')}/${DateTime.now().month.toString().padLeft(2,'0')}/${DateTime.now().year}'],
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final filename = 'faturamento_${billing.clientName.replaceAll(' ', '_')}_${billing.month.toString().padLeft(2,'0')}_${billing.year}.csv';
    final bytes = Uint8List.fromList('\uFEFF$csv'.codeUnits);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV "$filename" baixado!'), backgroundColor: AppTheme.success));
    }
  }

  Widget _orderTypeStat(String label, int count, String price, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            Text(price, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? AppTheme.textPrimary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
