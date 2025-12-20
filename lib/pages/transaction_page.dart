import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/notifier.dart';
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

  void reload() {
    if (!mounted) return;
    setState(() {
      transactions = TransactionService.getTransactions();
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case TransactionService.statusPaid:
        return Colors.green;
      case TransactionService.statusPending:
        return Colors.blue;
      case TransactionService.statusVoided:
        return Colors.orange;
      case TransactionService.statusRefunded:
        return Colors.red;
      case TransactionService.statusCanceled:
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case TransactionService.statusPaid:
        return Icons.check_circle;
      case TransactionService.statusPending:
        return Icons.hourglass_bottom;
      case TransactionService.statusVoided:
        return Icons.block;
      case TransactionService.statusRefunded:
        return Icons.reply;
      case TransactionService.statusCanceled:
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notify(context, msg, error: error);
    });
  }

  Future<String?> _askReason({
    required String title,
    required String hint,
  }) async {
    String value = '';
    final res = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            maxLines: 3,
            onChanged: (v) => value = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, value.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    return res;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: c),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required BuildContext sheetCtx,
    required Map<String, dynamic> trx,
    required String userId,
    required String status,
  }) {
    final trxId = trx['id'].toString();
    final isPending = status == TransactionService.statusPending;
    final isPaid = status == TransactionService.statusPaid;
    final isFinal = !isPending && !isPaid;

    Future<void> runPaid() async {
      try {
        final ok = await _confirm(
          title: 'Konfirmasi',
          message: 'Set transaksi ini jadi PAID?\nStok akan berkurang.',
        );
        if (!ok) return;
        await TransactionService.markAsPaid(trxId: trxId, userId: userId);
        _toast('Status jadi PAID');
        Navigator.pop(sheetCtx);
        reload();
      } catch (e) {
        _toast(e.toString(), error: true);
      }
    }

    Future<void> runVoid({required String title}) async {
      final reason = await _askReason(
        title: title,
        hint: 'Contoh: salah input / customer batal',
      );
      if (reason == null) return;
      if (reason.trim().isEmpty) {
        _toast('Alasan wajib diisi', error: true);
        return;
      }
      try {
        final ok = await _confirm(
          title: 'Konfirmasi',
          message: 'Yakin VOID transaksi ini?',
        );
        if (!ok) return;
        await TransactionService.voidTransaction(
          trxId: trxId,
          userId: userId,
          reason: reason,
        );
        _toast(isPaid ? 'Transaksi VOIDED (stok balik)' : 'Transaksi VOIDED');
        Navigator.pop(sheetCtx);
        reload();
      } catch (e) {
        _toast(e.toString(), error: true);
      }
    }

    Future<void> runRefund() async {
      final reason = await _askReason(
        title: 'Refund Transaksi',
        hint: 'Contoh: uang dikembalikan',
      );
      if (reason == null) return;
      if (reason.trim().isEmpty) {
        _toast('Alasan wajib diisi', error: true);
        return;
      }
      try {
        final ok = await _confirm(
          title: 'Konfirmasi',
          message: 'Yakin REFUND transaksi ini?',
        );
        if (!ok) return;
        await TransactionService.refundTransaction(
          trxId: trxId,
          userId: userId,
          reason: reason,
        );
        _toast('Transaksi REFUNDED (stok balik)');
        Navigator.pop(sheetCtx);
        reload();
      } catch (e) {
        _toast(e.toString(), error: true);
      }
    }

    Future<void> runCancel({required String title}) async {
      final reason = await _askReason(
        title: title,
        hint: 'Contoh: customer batal / nominal salah',
      );
      if (reason == null) return;
      if (reason.trim().isEmpty) {
        _toast('Alasan wajib diisi', error: true);
        return;
      }
      try {
        final ok = await _confirm(
          title: 'Konfirmasi',
          message: 'Yakin CANCEL transaksi ini?',
        );
        if (!ok) return;
        await TransactionService.cancelTransaction(
          trxId: trxId,
          userId: userId,
          reason: reason,
        );
        _toast('Transaksi CANCELED');
        Navigator.pop(sheetCtx);
        reload();
      } catch (e) {
        _toast(e.toString(), error: true);
      }
    }

    if (isFinal) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.6),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text('Status sudah final. Tidak bisa diubah lagi.'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aksi', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),

        if (isPending)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: runPaid,
              icon: const Icon(Icons.check_circle),
              label: const Text('Tandai sebagai PAID'),
            ),
          ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => runVoid(
                  title: isPending ? 'Void Transaksi (Pending)' : 'Void Transaksi',
                ),
                icon: const Icon(Icons.block),
                label: const Text('Void'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => runCancel(
                  title: isPaid ? 'Cancel Transaksi (Paid)' : 'Cancel Transaksi',
                ),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ),

        if (isPaid) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: runRefund,
              icon: const Icon(Icons.reply),
              label: const Text('Refund'),
            ),
          ),
        ],

        const SizedBox(height: 8),
        Text(
          isPending
              ? '• PAID: stok berkurang\n• VOID/CANCEL: transaksi dibatalkan'
              : '• VOID/REFUND/CANCEL: stok akan kembali',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  void openDetail(Map<String, dynamic> trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: MediaQuery.of(sheetCtx)
                .viewInsets
                .add(const EdgeInsets.fromLTRB(16, 8, 16, 16)),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: TransactionService.getTransactionItems(trx['id'].toString()),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snap.hasError) {
                  return SizedBox(
                    height: 260,
                    child: Center(child: Text('Error items: ${snap.error}')),
                  );
                }

                final items = snap.data ?? [];
                final date = DateTime.parse(trx['created_at'].toString());
                final df = DateFormat('dd/MM/yyyy HH:mm');
                final status =
                    (trx['status'] ?? TransactionService.statusPending).toString();
                final reason = (trx['status_reason'] ?? '').toString();
                final user = Supabase.instance.client.auth.currentUser;

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Detail Transaksi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _statusChip(status),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow(Icons.calendar_month, 'Tanggal', df.format(date)),
                            const SizedBox(height: 6),
                            _infoRow(
                              Icons.person,
                              'Kasir',
                              (trx['cashier_name'] ?? '-').toString(),
                            ),
                            const SizedBox(height: 6),
                            _infoRow(
                              Icons.payments,
                              'Pembayaran',
                              (trx['payment_method'] ?? '-').toString(),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.receipt_long, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Total',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Text(
                                  'Rp ${trx['total'] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.6),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('Alasan: $reason')),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Actions + Print Button
                      if (user != null) ...[
                        _buildActionButtons(
                          sheetCtx: sheetCtx,
                          trx: trx,
                          userId: user.id,
                          status: status,
                        ),
                        const SizedBox(height: 10),

                        // ✅ BUTTON PRINT (tanpa logika dulu)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: () {
                              // TODO: implement print logic later
                              _toast('Fitur print struk belum diaktifkan');
                            },
                            icon: const Icon(Icons.print),
                            label: const Text('Print Struk'),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Login diperlukan untuk mengubah status transaksi.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ✅ BUTTON PRINT (tetap tampil walau belum login, optional)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: () {
                              // TODO: implement print logic later
                              _toast('Fitur print struk belum diaktifkan');
                            },
                            icon: const Icon(Icons.print),
                            label: const Text('Print Struk'),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],

                      const Text('Item', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),

                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Tidak ada item'),
                        )
                      else
                        ...items.map((i) {
                          final product = i['products'] as Map<String, dynamic>?;
                          final name = product?['name']?.toString() ?? '-';
                          final qty = i['qty'];
                          final price = i['price'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_cafe, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Qty: $qty • Rp $price'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Transaksi')),
      body: RefreshIndicator(
        onRefresh: () async => reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: transactions,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Error: ${snap.error}')),
                ],
              );
            }

            final data = snap.data ?? [];
            if (data.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Belum ada transaksi')),
                ],
              );
            }

            final df = DateFormat('dd/MM/yyyy');

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = data[i];
                final date = DateTime.parse(t['created_at'].toString());
                final status =
                    (t['status'] ?? TransactionService.statusPending).toString();

                return Card(
                  child: ListTile(
                    onTap: () => openDetail(t),
                    title: Text(
                      'Rp ${t['total']}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${(t['payment_method'] ?? '-')} • ${df.format(date)} • ${(t['cashier_name'] ?? '-').toString()}',
                    ),
                    leading: Container(
                      width: 12,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    trailing: _statusChip(status),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
