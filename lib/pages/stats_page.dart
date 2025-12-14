import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late Future<Map<String, dynamic>> stats;

  @override
  void initState() {
    super.initState();
    stats = loadStats();
  }

  Future<Map<String, dynamic>> loadStats() async {
    final db = Supabase.instance.client;

    final res = await db
        .from('transactions')
        .select('total, payment_method, created_at');

    int totalTransaksi = res.length;
    int totalPendapatan = 0;
    int cash = 0;
    int qris = 0;

    int todayTransaksi = 0;
    int todayPendapatan = 0;

    final now = DateTime.now();

    for (final t in res) {
      final total = t['total'] as int;
      final method = t['payment_method'];
      final date = DateTime.parse(t['created_at']);

      totalPendapatan += total;

      if (method == 'cash') cash++;
      if (method == 'qris') qris++;

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        todayTransaksi++;
        todayPendapatan += total;
      }
    }

    return {
      'totalTransaksi': totalTransaksi,
      'totalPendapatan': totalPendapatan,
      'avgTransaksi': totalTransaksi == 0
          ? 0
          : (totalPendapatan ~/ totalTransaksi),
      'todayTransaksi': todayTransaksi,
      'todayPendapatan': todayPendapatan,
      'cash': cash,
      'qris': qris,
    };
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.decimalPattern('id');

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Penjualan')),
      body: FutureBuilder(
        future: stats,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final s = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              statCard(
                title: 'Total Pendapatan',
                value: 'Rp ${f.format(s['totalPendapatan'])}',
                icon: Icons.attach_money,
              ),
              statCard(
                title: 'Total Transaksi',
                value: '${s['totalTransaksi']} transaksi',
                icon: Icons.receipt_long,
              ),
              statCard(
                title: 'Rata-rata Transaksi',
                value: 'Rp ${f.format(s['avgTransaksi'])}',
                icon: Icons.analytics,
              ),
              const Divider(height: 32),

              statCard(
                title: 'Hari Ini',
                value:
                    '${s['todayTransaksi']} transaksi • Rp ${f.format(s['todayPendapatan'])}',
                icon: Icons.today,
              ),
              const Divider(height: 32),

              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              statCard(
                title: 'Cash',
                value: '${s['cash']} transaksi',
                icon: Icons.payments,
              ),
              statCard(
                title: 'QRIS',
                value: '${s['qris']} transaksi',
                icon: Icons.qr_code,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
