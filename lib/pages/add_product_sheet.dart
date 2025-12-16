import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/notifier.dart';
import '../services/categorie_service.dart';
import '../services/product_service.dart';
import '../services/storage_service.dart';

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
  final stock = TextEditingController(text: '0');

  bool loading = false;

  String? categoryId;

  File? _pickedImage;
  String? _existingImageUrl;

  bool stockEnabled = true;

  late Future<List<Map<String, dynamic>>> categories;

  @override
  void initState() {
    super.initState();
    categories = CategoryService.getCategories();

    if (widget.product != null) {
      final p = widget.product!;
      name.text = (p['name'] ?? '').toString();
      price.text = (p['price'] ?? '').toString();
      stock.text = (p['stock'] ?? 0).toString();
      categoryId = (p['category_id'] ?? '').toString();
      _existingImageUrl = (p['image_url'] ?? '').toString();
      stockEnabled = (p['stock_enabled'] ?? true) == true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    stock.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (x == null) return;

    setState(() => _pickedImage = File(x.path));
  }

  Widget _imageBox() {
    return InkWell(
      onTap: pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade900,
        ),
        clipBehavior: Clip.antiAlias,
        child: _pickedImage != null
            ? Image.file(_pickedImage!, fit: BoxFit.cover)
            : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
            ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
            : const Center(child: Text('Tap untuk pilih foto produk')),
      ),
    );
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty ||
        price.text.trim().isEmpty ||
        categoryId == null) {
      notify(context, 'Nama, harga, dan kategori wajib diisi', error: true);
      return;
    }

    final priceVal = int.tryParse(price.text.trim());
    if (priceVal == null) {
      notify(context, 'Harga harus angka', error: true);
      return;
    }

    final stockVal = int.tryParse(stock.text.trim()) ?? 0;

    setState(() => loading = true);
    try {
      String? imageUrl = _existingImageUrl;

      if (_pickedImage != null) {
        imageUrl = await StorageService.uploadProductImage(_pickedImage!);
      }

      if (widget.product == null) {
        await ProductService.addProduct(
          name: name.text.trim(),
          price: priceVal,
          categoryId: categoryId!,
          imageUrl: imageUrl,
          stock: stockVal,
          stockEnabled: stockEnabled,
        );
      } else {
        await ProductService.updateProduct(
          id: widget.product!['id'].toString(),
          name: name.text.trim(),
          price: priceVal,
          categoryId: categoryId!,
          imageUrl: imageUrl,
          isActive: (widget.product!['is_active'] ?? true) == true,
          stock: stockVal,
          stockEnabled: stockEnabled,
        );
      }

      widget.onSaved();
      notify(context, 'Produk tersimpan');
    } catch (e) {
      notify(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
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

          _imageBox(),
          const SizedBox(height: 12),

          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nama Produk'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Harga'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Stok (angka)'),
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Stok Aktif'),
            subtitle: const Text(
              'Kalau OFF, stok tidak berkurang saat transaksi',
            ),
            value: stockEnabled,
            onChanged: (v) => setState(() => stockEnabled = v),
          ),

          const SizedBox(height: 12),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: categories,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              final data = snap.data ?? [];
              return DropdownButtonFormField<String>(
                value: categoryId,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: data
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id'].toString(),
                        child: Text(c['name'].toString()),
                      ),
                    )
                    .toList(),
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
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SIMPAN'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
