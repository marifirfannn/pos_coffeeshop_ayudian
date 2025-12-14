import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  static Future<List<Map<String, dynamic>>> getReport(
    DateTime from,
    DateTime to,
  ) async {
    return await Supabase.instance.client
        .from('transactions')
        .select()
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String());
  }
}
