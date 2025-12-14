import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await _db
        .from('products')
        .select('*, categories(name)')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> addProduct({
    required String name,
    required int price,
    required String categoryId,
    String? imageUrl,
  }) async {
    await _db.from('products').insert({
      'name': name,
      'price': price,
      'category_id': categoryId,
      'image_url': imageUrl,
      'is_active': true,
    });
  }

  static Future<void> updateProduct({
    required String id,
    required String name,
    required int price,
    required String categoryId,
    String? imageUrl,
    required bool isActive,
  }) async {
    await _db
        .from('products')
        .update({
          'name': name,
          'price': price,
          'category_id': categoryId,
          'image_url': imageUrl,
          'is_active': isActive,
        })
        .eq('id', id);
  }

  static Future<void> deleteProduct(String id) async {
    await _db.from('products').delete().eq('id', id);
  }

  static Future<void> toggleActive(String id, bool value) async {
    await _db.from('products').update({'is_active': value}).eq('id', id);
  }
}
