import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionService {
  static final _db = Supabase.instance.client;

  /// ================= CREATE TRANSACTION =================
  static Future<void> createTransaction({
    required String userId,
    required int total,
    required String payment,
    required List<Map<String, dynamic>> items,
  }) async {
    final trx = await _db
        .from('transactions')
        .insert({
          'user_id': userId,
          'total': total,
          'payment_method': payment,
          'status': 'paid',
        })
        .select()
        .single();

    final trxId = trx['id'];

    await _db
        .from('transaction_items')
        .insert(
          items
              .map(
                (i) => {
                  'transaction_id': trxId,
                  'product_id': i['id'],
                  'price': i['price'],
                  'qty': i['qty'],
                },
              )
              .toList(),
        );
  }

  /// ================= GET ALL TRANSACTIONS =================
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final res = await _db
        .from('transactions')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  /// ================= GET DETAIL ITEMS =================
  static Future<List<Map<String, dynamic>>> getTransactionItems(
    String trxId,
  ) async {
    final res = await _db
        .from('transaction_items')
        .select('qty, price, products(name)')
        .eq('transaction_id', trxId);

    return List<Map<String, dynamic>>.from(res);
  }
}
