import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/notifier.dart';
import '../services/product_service.dart';
import 'add_product_sheet.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late Future<List<Map<String, dynamic>>> products;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    products = ProductService.getProducts();
  }

  void openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddProductSheet(
        onSaved: () {
          Navigator.pop(context);
          setState(load);
        },
      ),
    );
  }

  void openEdit(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddProductSheet(
        product: product,
        onSaved: () {
          Navigator.pop(context);
          setState(load);
        },
      ),
    );
  }

  Future<void> openStockManager(Map<String, dynamic> product) async {
    final id = product['id'].toString();
    int stock = (product['stock'] ?? 0) is int
        ? product['stock'] as int
        : int.tryParse(product['stock'].toString()) ?? 0;
    bool stockEnabled = (product['stock_enabled'] ?? true) as bool;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: MediaQuery.of(
                ctx,
              ).viewInsets.add(const EdgeInsets.all(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Stok • ${product['name']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stok Aktif'),
                    subtitle: const Text(
                      'Kalau OFF, stok tidak dihitung otomatis',
                    ),
                    value: stockEnabled,
                    onChanged: (v) async {
                      setLocal(() => stockEnabled = v);
                      await ProductService.toggleStockEnabled(id, v);
                      notify(context, 'Stok ${v ? 'aktif' : 'nonaktif'}');
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ProductService.adjustStock(
                              productId: id,
                              delta: -1,
                            );
                            setLocal(() => stock = stock - 1);
                          },
                          icon: const Icon(Icons.remove),
                          label: const Text('Kurang'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade900,
                        ),
                        child: Text(
                          '$stock',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ProductService.adjustStock(
                              productId: id,
                              delta: 1,
                            );
                            setLocal(() => stock = stock + 1);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Set stok (angka)',
                      hintText: 'Misal: 25',
                    ),
                    onSubmitted: (v) async {
                      final val = int.tryParse(v) ?? stock;
                      await ProductService.setStock(productId: id, stock: val);
                      setLocal(() => stock = val);
                      notify(context, 'Stok diset ke $val');
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('SELESAI'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    setState(load);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: openAdd)],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: products,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('Belum ada produk'));
          }

          final data = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = data[i];
              final category = (p['categories']?['name'] ?? '-').toString();
              final price = (p['price'] ?? 0).toString();
              final stock = (p['stock'] ?? 0).toString();
              final stockEnabled = (p['stock_enabled'] ?? true) == true;
              final isActive = (p['is_active'] ?? true) == true;

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.coffee),
                  title: Text(p['name'].toString()),
                  subtitle: Text(
                    '$category • Rp $price\nStok: $stock ${stockEnabled ? '(ON)' : '(OFF)'}',
                  ),
                  isThreeLine: true,
                  onTap: () => openStockManager(p),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: (v) async {
                          await ProductService.toggleActive(
                            p['id'].toString(),
                            v,
                          );
                          setState(load);
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            openEdit(p);
                            return;
                          }
                          if (v == 'delete') {
                            await ProductService.deleteProduct(
                              p['id'].toString(),
                            );
                            notify(context, 'Produk dihapus');
                            setState(load);
                            return;
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
                    ],
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
