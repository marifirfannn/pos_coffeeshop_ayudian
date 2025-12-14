import 'package:flutter/material.dart';
import '../services/categorie_service.dart';
import '../services/product_service.dart';
import '../core/notifier.dart';

class AddProductSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? product;

  const AddProductSheet({super.key, required this.onSaved, this.product});

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final name = TextEditingController();
  final price = TextEditingController();
  String? categoryId;
  bool loading = false;

  late Future<List> categories;

  @override
  void initState() {
    super.initState();
    categories = CategoryService.getCategories();

    if (widget.product != null) {
      name.text = widget.product!['name'];
      price.text = widget.product!['price'].toString();
      categoryId = widget.product!['category_id'];
    }
  }

  Future<void> save() async {
    if (name.text.isEmpty || price.text.isEmpty || categoryId == null) {
      notify(context, 'Semua field wajib diisi', error: true);
      return;
    }

    final p = int.tryParse(price.text);
    if (p == null) {
      notify(context, 'Harga harus angka', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      if (widget.product == null) {
        await ProductService.addProduct(
          name: name.text.trim(),
          price: p,
          categoryId: categoryId!,
        );
        notify(context, 'Produk ditambahkan');
      } else {
        await ProductService.updateProduct(
          id: widget.product!['id'],
          name: name.text.trim(),
          price: p,
          categoryId: categoryId!,
          imageUrl: widget.product!['image_url'],
          isActive: widget.product!['is_active'],
        );
        notify(context, 'Produk diupdate');
      }

      widget.onSaved();
    } catch (e) {
      notify(context, 'Gagal simpan produk', error: true);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.product == null ? 'Tambah Produk' : 'Edit Produk',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nama Produk'),
          ),

          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Harga'),
          ),

          const SizedBox(height: 12),

          FutureBuilder(
            future: categories,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (!snap.hasData || (snap.data as List).isEmpty) {
                return const Text('Kategori belum tersedia');
              }

              final data = snap.data as List;

              return DropdownButtonFormField<String>(
                value: categoryId,
                hint: const Text('Pilih Kategori'),
                items: data.map<DropdownMenuItem<String>>((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text(c['name']),
                  );
                }).toList(),
                onChanged: (v) => setState(() => categoryId = v),
              );
            },
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : save,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }
}
