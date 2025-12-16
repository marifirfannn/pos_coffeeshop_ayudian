import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/notifier.dart';
import '../services/report_service.dart';
import '../services/transaction_service.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTimeRange range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  /// '' all, 'cash', 'qris'
  String paymentFilter = '';

  /// '' all, 'paid', 'pending', 'voided', ...
  String statusFilter = '';

  /// daily | weekly | monthly | custom
  String quickRange = 'weekly';

  final physicalCash = TextEditingController();

  late Future<Map<String, dynamic>> stats;

  @override
  void initState() {
    super.initState();
    stats = _loadStats(forRange: _normalizedRange(range));
  }

  @override
  void dispose() {
    physicalCash.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  int asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999, 999);

  DateTimeRange _normalizedRange(DateTimeRange r) {
    // FIX: include full last day
    return DateTimeRange(start: _startOfDay(r.start), end: _endOfDay(r.end));
  }

  DateTimeRange _dailyRange() {
    final now = DateTime.now();
    return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
  }

  DateTimeRange _weeklyRange() {
    final now = DateTime.now();
    // 7 hari termasuk hari ini
    final start = _startOfDay(now.subtract(const Duration(days: 6)));
    return DateTimeRange(start: start, end: _endOfDay(now));
  }

  DateTimeRange _monthlyRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return DateTimeRange(start: start, end: _endOfDay(now));
  }

  String rupiah(int v) => 'Rp ${NumberFormat('#,###', 'id_ID').format(v)}';

  // ---------- Reload (ANTI BUG: range berubah tapi data ga ikut) ----------
  void _reloadWith({
    DateTimeRange? newRange,
    String? newQuickRange,
    String? newPaymentFilter,
    String? newStatusFilter,
  }) {
    final updatedRange = _normalizedRange(newRange ?? range);
    setState(() {
      if (newRange != null) range = newRange;
      if (newQuickRange != null) quickRange = newQuickRange;
      if (newPaymentFilter != null) paymentFilter = newPaymentFilter;
      if (newStatusFilter != null) statusFilter = newStatusFilter;

      // IMPORTANT: set future based on updated params (bukan state lama)
      stats = _loadStats(
        forRange: updatedRange,
        payment: (newPaymentFilter ?? paymentFilter).isEmpty
            ? null
            : (newPaymentFilter ?? paymentFilter),
        status: (newStatusFilter ?? statusFilter).isEmpty
            ? null
            : (newStatusFilter ?? statusFilter),
      );
    });
  }

  void _refresh() {
    _reloadWith(); // reload pakai state sekarang
  }

  void applyQuickRange(String mode) {
    if (mode == 'daily') {
      _reloadWith(newRange: _dailyRange(), newQuickRange: 'daily');
    } else if (mode == 'weekly') {
      _reloadWith(newRange: _weeklyRange(), newQuickRange: 'weekly');
    } else if (mode == 'monthly') {
      _reloadWith(newRange: _monthlyRange(), newQuickRange: 'monthly');
    }
  }

  Future<void> pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: range,
    );
    if (r == null) return;
    _reloadWith(newRange: r, newQuickRange: 'custom');
  }

  // ---------- Data builder ----------
  List<_DayPoint> _buildDailySeries(
    DateTime start,
    DateTime end,
    Map<String, int> map,
  ) {
    final s = _startOfDay(start);
    final e = _startOfDay(end);
    final points = <_DayPoint>[];

    DateTime cur = s;
    while (!cur.isAfter(e)) {
      final key = DateFormat('yyyy-MM-dd').format(cur);
      points.add(_DayPoint(date: cur, value: map[key] ?? 0));
      cur = cur.add(const Duration(days: 1));
    }
    return points;
  }

  Future<Map<String, dynamic>> _loadStats({
    required DateTimeRange forRange,
    String? payment,
    String? status,
  }) async {
    final rows = await ReportService.getReport(
      from: forRange.start,
      to: forRange.end,
      paymentMethod: payment,
      status: status,
    );

    int totalTrx = rows.length;
    int omzet = 0;

    int cashTrx = 0;
    int nonCashTrx = 0;

    int cashAmount = 0;
    int nonCashAmount = 0;

    final Map<String, int> omzetPerDay = {};
    final Map<String, _TopProduct> productAgg = {};

    for (final rr in rows) {
      final total = asInt(rr['total']);
      omzet += total;

      final method = (rr['payment_method'] ?? '').toString().toLowerCase();
      if (method == 'cash') {
        cashTrx++;
        cashAmount += total;
      } else {
        nonCashTrx++;
        nonCashAmount += total;
      }

      final created = DateTime.tryParse((rr['created_at'] ?? '').toString());
      if (created != null) {
        final key = DateFormat('yyyy-MM-dd').format(created);
        omzetPerDay[key] = (omzetPerDay[key] ?? 0) + total;
      }

      // Top products (butuh join items)
      final dynamic itemsAny = rr['items'] ?? rr['transaction_items'];
      if (itemsAny is List) {
        for (final it in itemsAny) {
          if (it is! Map) continue;

          final qty = asInt(it['qty']);
          final price = asInt(it['price']);

          String name = '';
          final prodMap = it['products'];
          if (prodMap is Map && prodMap['name'] != null) {
            name = prodMap['name'].toString();
          } else if (it['product_name'] != null) {
            name = it['product_name'].toString();
          } else if (it['name'] != null) {
            name = it['name'].toString();
          }
          name = name.trim();
          if (name.isEmpty) continue;

          final addRevenue = qty * price;
          final existing = productAgg[name];
          if (existing == null) {
            productAgg[name] = _TopProduct(
              name: name,
              qty: qty,
              revenue: addRevenue,
            );
          } else {
            productAgg[name] = existing.copyWith(
              qty: existing.qty + qty,
              revenue: existing.revenue + addRevenue,
            );
          }
        }
      }
    }

    final series = _buildDailySeries(forRange.start, forRange.end, omzetPerDay);

    final topProducts = productAgg.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    return {
      'range': forRange,
      'rows': rows,
      'totalTrx': totalTrx,
      'omzet': omzet,
      'cashTrx': cashTrx,
      'nonCashTrx': nonCashTrx,
      'cashAmount': cashAmount,
      'nonCashAmount': nonCashAmount,
      'series': series,
      'topProducts': topProducts.take(8).toList(),
    };
  }

  // ---------- Export ----------
  Future<void> exportPdf(List<Map<String, dynamic>> rows) async {
    try {
      final nr = _normalizedRange(range);
      final file = await ReportService.exportPdf(
        rows: rows,
        from: nr.start,
        to: nr.end,
      );
      await ReportService.shareFile(file);
    } catch (e) {
      notify(context, e.toString(), error: true);
    }
  }

  Future<void> exportExcel(List<Map<String, dynamic>> rows) async {
    try {
      final nr = _normalizedRange(range);
      final file = await ReportService.exportExcel(
        rows: rows,
        from: nr.start,
        to: nr.end,
      );
      await ReportService.shareFile(file);
    } catch (e) {
      notify(context, e.toString(), error: true);
    }
  }

  // ---------- UI parts ----------
  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: const Text('Harian'),
            selected: quickRange == 'daily',
            onSelected: (_) => applyQuickRange('daily'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Mingguan'),
            selected: quickRange == 'weekly',
            onSelected: (_) => applyQuickRange('weekly'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Bulanan'),
            selected: quickRange == 'monthly',
            onSelected: (_) => applyQuickRange('monthly'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Custom'),
            selected: quickRange == 'custom',
            onSelected: (_) => pickRange(),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdowns() {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 420;

        final metode = DropdownButtonFormField<String>(
          value: paymentFilter,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Metode',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: '', child: Text('Semua')),
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'qris', child: Text('Non-cash (QRIS)')),
          ],
          onChanged: (v) => _reloadWith(newPaymentFilter: v ?? ''),
        );

        final status = DropdownButtonFormField<String>(
          value: statusFilter,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: '', child: Text('Semua')),
            DropdownMenuItem(
              value: TransactionService.statusPaid,
              child: Text('PAID'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusPending,
              child: Text('PENDING'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusVoided,
              child: Text('VOID'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusRefunded,
              child: Text('REFUND'),
            ),
            DropdownMenuItem(
              value: TransactionService.statusCanceled,
              child: Text('CANCEL'),
            ),
          ],
          onChanged: (v) => _reloadWith(newStatusFilter: v ?? ''),
        );

        if (isNarrow) {
          return Column(children: [metode, const SizedBox(height: 12), status]);
        }

        return Row(
          children: [
            Expanded(child: metode),
            const SizedBox(width: 12),
            Expanded(child: status),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Penjualan'),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: pickRange),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: stats,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Gagal load rekap: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: Text('Gagal load rekap'));
          }

          final s = snap.data!;

          final DateTimeRange nr = (s['range'] is DateTimeRange)
              ? (s['range'] as DateTimeRange)
              : _normalizedRange(range);

          final rows = (s['rows'] is List)
              ? List<Map<String, dynamic>>.from(s['rows'] as List)
              : <Map<String, dynamic>>[];

          final series = (s['series'] is List<_DayPoint>)
              ? (s['series'] as List<_DayPoint>)
              : <_DayPoint>[];

          final topProducts = (s['topProducts'] is List<_TopProduct>)
              ? (s['topProducts'] as List<_TopProduct>)
              : <_TopProduct>[];

          final cashAmount = asInt(s['cashAmount']);
          final nonCashAmount = asInt(s['nonCashAmount']);

          final phys = int.tryParse(physicalCash.text.trim()) ?? 0;
          final selisih = phys - cashAmount;

          final titleRange = '${df.format(nr.start)} - ${df.format(nr.end)}';

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Filter Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Filter & Periode',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: pickRange,
                            icon: const Icon(Icons.edit_calendar),
                            label: const Text('Custom'),
                          ),
                        ],
                      ),
                      Text(
                        titleRange,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      _chipRow(),
                      const SizedBox(height: 12),
                      _filterDropdowns(),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Summary
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  children: [
                    _summaryCard(
                      title: 'Total Transaksi',
                      value: '${asInt(s['totalTrx'])}',
                      icon: Icons.receipt_long,
                    ),
                    _summaryCard(
                      title: 'Total Omzet',
                      value: rupiah(asInt(s['omzet'])),
                      icon: Icons.trending_up,
                    ),
                    _summaryCard(
                      title: 'Cash',
                      value: rupiah(cashAmount),
                      icon: Icons.payments,
                      subtitle: '${asInt(s['cashTrx'])} trx',
                    ),
                    _summaryCard(
                      title: 'Non-Cash',
                      value: rupiah(nonCashAmount),
                      icon: Icons.qr_code,
                      subtitle: '${asInt(s['nonCashTrx'])} trx',
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Kas & Selisih
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kas (Shift)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: physicalCash,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Uang fisik (input manual)',
                          hintText: 'Misal: 250000',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _summaryCard(
                        title: 'Selisih (Uang fisik - Total cash)',
                        value: rupiah(selisih),
                        icon: Icons.compare_arrows,
                        subtitle: selisih == 0
                            ? 'Balance'
                            : (selisih > 0 ? 'Lebih' : 'Kurang'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Column Chart
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart),
                          SizedBox(width: 8),
                          Text(
                            'Grafik Omzet (Column)',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 170,
                        width: double.infinity,
                        child: _ColumnChart(points: series),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Periode: ${df.format(nr.start)} s/d ${df.format(nr.end)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Export
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Tidak ada data untuk filter ini'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => exportPdf(rows),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Export PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => exportExcel(rows),
                          icon: const Icon(Icons.grid_on),
                          label: const Text('Export Excel'),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 14),

                // Top products
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_cafe),
                          SizedBox(width: 8),
                          Text(
                            'Produk Terlaris',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (topProducts.isEmpty)
                        Text(
                          'Belum ada data item produk di report.\n'
                          'Kalau mau muncul, ReportService.getReport() harus join transaction_items + products(name).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.85),
                          ),
                        )
                      else
                        ...topProducts.map((p) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  'x${p.qty}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  rupiah(p.revenue),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================= Models =================
class _DayPoint {
  final DateTime date;
  final int value;
  _DayPoint({required this.date, required this.value});
}

class _TopProduct {
  final String name;
  final int qty;
  final int revenue;

  _TopProduct({required this.name, required this.qty, required this.revenue});

  _TopProduct copyWith({String? name, int? qty, int? revenue}) {
    return _TopProduct(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      revenue: revenue ?? this.revenue,
    );
  }
}

// ================= Column Chart =================
class _ColumnChart extends StatelessWidget {
  final List<_DayPoint> points;
  const _ColumnChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ColumnChartPainter(
        points: points,
        dividerColor: Theme.of(context).dividerColor,
        labelStyle:
            (Theme.of(context).textTheme.bodySmall ??
                    const TextStyle(fontSize: 11))
                .copyWith(fontSize: 10),
      ),
    );
  }
}

class _ColumnChartPainter extends CustomPainter {
  final List<_DayPoint> points;
  final Color dividerColor;
  final TextStyle labelStyle;

  _ColumnChartPainter({
    required this.points,
    required this.dividerColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 40.0;
    final rightPad = 8.0;
    final topPad = 10.0;
    final bottomPad = 22.0;

    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final maxVal = max(
      1,
      points.isEmpty ? 0 : points.map((e) => e.value).reduce(max),
    );

    final gridPaint = Paint()
      ..color = dividerColor.withOpacity(0.8)
      ..strokeWidth = 1;

    // horizontal grid (0%, 50%, 100%)
    for (int i = 0; i <= 2; i++) {
      final y = topPad + h * (i / 2);
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + w, y), gridPaint);
    }

    _drawText(canvas, _shortNum(maxVal), Offset(0, topPad - 4));
    _drawText(
      canvas,
      _shortNum((maxVal / 2).round()),
      Offset(0, topPad + h / 2 - 4),
    );

    if (points.isEmpty) {
      _drawText(canvas, 'No data', Offset(leftPad + 8, topPad + 8));
      return;
    }

    final count = points.length;
    final gap = 6.0;
    final barW = max(6.0, (w - gap * (count - 1)) / count);

    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.withOpacity(0.85);

    for (int i = 0; i < count; i++) {
      final p = points[i];
      final barH = (p.value / maxVal) * h;

      final x = leftPad + i * (barW + gap);
      final y = topPad + (h - barH);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, barPaint);

      // x label (tampilkan beberapa aja biar ga numpuk)
      final showLabel =
          count <= 7 || i == 0 || i == count - 1 || i == (count / 2).floor();
      if (showLabel) {
        final label = DateFormat('dd/MM').format(p.date);
        _drawText(
          canvas,
          label,
          Offset(x - 2, topPad + h + 4),
          style: labelStyle,
        );
      }
    }
  }

  String _shortNum(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}rb';
    return v.toString();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    TextStyle? style,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style ?? labelStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ColumnChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.labelStyle != labelStyle;
  }
}
