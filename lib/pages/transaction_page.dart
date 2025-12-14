import 'package:flutter/material.dart';
import '../services/transaction_service.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  late Future<List<Map<String, dynamic>>> transactions;

  @override
  void initState() {
    super.initState();
    transactions = TransactionService.getTransactions();
  }

  void openDetail(Map<String, dynamic> trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: TransactionService.getTransactionItems(trx['id']),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snap.hasData || snap.data!.isEmpty) {
                return const Text('Tidak ada item');
              }

              final items = snap.data!;
              final date = DateTime.parse(trx['created_at']);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal: ${date.day}/${date.month}/${date.year} '
                    '${date.hour.toString().padLeft(2, '0')}:'
                    '${date.minute.toString().padLeft(2, '0')}',
                  ),
                  Text('Pembayaran: ${trx['payment_method']}'),

                  const Divider(),

                  ...items.map((i) {
                    final product = i['products'] as Map<String, dynamic>?;

                    final name = product?['name'] ?? '-';
                    final qty = (i['qty'] as num).toInt();
                    final price = (i['price'] as num).toInt();

                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: Text('Rp $price x $qty'),
                      trailing: Text(
                        'Rp ${price * qty}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),

                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'TOTAL: Rp ${trx['total']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('PRINT STRUK'),
                      onPressed: () {},
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Transaksi')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: transactions,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('Belum ada transaksi'));
          }

          final data = snap.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (_, i) {
              final t = data[i];
              final date = DateTime.parse(t['created_at']);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(
                    'Rp ${t['total']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${t['payment_method']} • ${date.day}/${date.month}/${date.year}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.receipt_long),
                    onPressed: () => openDetail(t),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
