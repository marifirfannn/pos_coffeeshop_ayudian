import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getReport({
    required DateTime from,
    required DateTime to,
    String? paymentMethod,
    String? status,
  }) async {
    var q = _db
        .from('transactions')
        .select(
          'id,user_id,total,payment_method,status,status_reason,created_at',
        );

    q = q.gte('created_at', from.toIso8601String());
    q = q.lte('created_at', to.toIso8601String());

    if (paymentMethod != null && paymentMethod.trim().isNotEmpty) {
      q = q.eq('payment_method', paymentMethod.trim());
    }
    if (status != null && status.trim().isNotEmpty) {
      q = q.eq('status', status.trim());
    }

    final res = await q.order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(res);

    final ids = rows
        .map((e) => e['user_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final names = await _fetchProfileNames(ids);

    return rows
        .map((t) => {...t, 'cashier_name': names[t['user_id']] ?? '-'})
        .toList();
  }

  static Future<File> exportPdf({
    required List<Map<String, dynamic>> rows,
    required DateTime from,
    required DateTime to,
    String fileNamePrefix = 'laporan_pos',
    int maxRows = 200,
  }) async {
    int totalTrx = rows.length;
    int omzet = 0;
    int cash = 0;
    int nonCash = 0;

    for (final r in rows) {
      final total = _asInt(r['total']);
      omzet += total;
      final pm = (r['payment_method'] ?? '').toString().toLowerCase();
      if (pm == 'cash') {
        cash += total;
      } else {
        nonCash += total;
      }
    }

    final df = DateFormat('yyyy-MM-dd');
    final dfDT = DateFormat('yyyy-MM-dd HH:mm');
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          final limited = rows.take(maxRows).toList();

          return [
            pw.Text(
              'Laporan POS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Periode: ${df.format(from)} s/d ${df.format(to)}'),
            pw.SizedBox(height: 12),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Rekap',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _kv('Total transaksi', totalTrx.toString()),
                  _kv('Total omzet', _rupiah(omzet)),
                  _kv('Total cash', _rupiah(cash)),
                  _kv('Total non-cash', _rupiah(nonCash)),
                ],
              ),
            ),

            pw.SizedBox(height: 14),
            pw.Text(
              'Detail Transaksi (max $maxRows baris)',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),

            pw.Table.fromTextArray(
              headers: const [
                'Tanggal',
                'Kasir',
                'Metode',
                'Status',
                'Total',
                'Alasan',
              ],
              data: limited.map((r) {
                final createdAt = DateTime.tryParse(
                  (r['created_at'] ?? '').toString(),
                );
                final dtStr = createdAt != null ? dfDT.format(createdAt) : '-';

                return [
                  dtStr,
                  (r['cashier_name'] ?? '-').toString(),
                  (r['payment_method'] ?? '-').toString(),
                  (r['status'] ?? '-').toString().toUpperCase(),
                  _rupiah(_asInt(r['total'])),
                  (r['status_reason'] ?? '').toString(),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final fn =
        "${fileNamePrefix}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf";
    final file = File('${dir.path}/$fn');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static Future<File> exportExcel({
    required List<Map<String, dynamic>> rows,
    required DateTime from,
    required DateTime to,
    String fileNamePrefix = 'laporan_transaksi',
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Jam'),
      TextCellValue('Kasir'),
      TextCellValue('Metode'),
      TextCellValue('Status'),
      TextCellValue('Total'),
      TextCellValue('Alasan'),
    ]);

    final dfDate = DateFormat('yyyy-MM-dd');
    final dfTime = DateFormat('HH:mm');

    for (final r in rows) {
      final createdAt = DateTime.tryParse((r['created_at'] ?? '').toString());
      final dateStr = createdAt != null ? dfDate.format(createdAt) : '-';
      final timeStr = createdAt != null ? dfTime.format(createdAt) : '-';

      sheet.appendRow([
        TextCellValue(dateStr),
        TextCellValue(timeStr),
        TextCellValue((r['cashier_name'] ?? '-').toString()),
        TextCellValue((r['payment_method'] ?? '-').toString()),
        TextCellValue((r['status'] ?? '-').toString().toUpperCase()),
        IntCellValue(_asInt(r['total'])),
        TextCellValue((r['status_reason'] ?? '').toString()),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal encode Excel');

    final dir = await getTemporaryDirectory();
    final fn =
        "${fileNamePrefix}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx";
    final file = File('${dir.path}/$fn');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<Map<String, String>> _fetchProfileNames(
    List<String> userIds,
  ) async {
    final map = <String, String>{};
    if (userIds.isEmpty) return map;

    // ambil unique
    final ids = userIds.toSet().toList();

    for (final id in ids) {
      try {
        final res = await _db
            .from('profiles')
            .select('id,name')
            .eq('id', id)
            .maybeSingle();

        if (res == null) {
          map[id] = '-';
        } else {
          final name = (res['name'] ?? '').toString();
          map[id] = name.isNotEmpty ? name : '-';
        }
      } catch (_) {
        map[id] = '-';
      }
    }

    return map;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _rupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(k)),
          pw.SizedBox(width: 10),
          pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
