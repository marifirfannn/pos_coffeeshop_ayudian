import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/categorie_service.dart';
import '../services/product_service.dart';
import '../services/storage_service.dart';
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

  final _picker = ImagePicker();
  File? _pickedImage;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    categories = CategoryService.getCategories();

    if (widget.product != null) {
      name.text = widget.product!['name'];
      price.text = widget.product!['price'].toString();
      categoryId = widget.product!['category_id'];
      _existingImageUrl = widget.product!['image_url'];
    }
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (xfile == null) return;

    setState(() => _pickedImage = File(xfile.path));
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
      // upload image kalau ada yang dipilih
      String? imageUrl = _existingImageUrl;
      if (_pickedImage != null) {
        imageUrl = await StorageService.uploadProductImage(_pickedImage!);
      }

      if (widget.product == null) {
        await ProductService.addProduct(
          name: name.text.trim(),
          price: p,
          categoryId: categoryId!,
          imageUrl: imageUrl,
        );
        notify(context, 'Produk ditambahkan');
      } else {
        await ProductService.updateProduct(
          id: widget.product!['id'],
          name: name.text.trim(),
          price: p,
          categoryId: categoryId!,
          imageUrl: imageUrl,
          isActive: widget.product!['is_active'],
        );
        notify(context, 'Produk diupdate');
      }

      widget.onSaved();
    } catch (e) {
      notify(context, 'Gagal simpan produk: $e', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _imageBox() {
    return InkWell(
      onTap: loading ? null : pickImage,
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _pickedImage != null
              ? Image.file(_pickedImage!, fit: BoxFit.cover)
              : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
              ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
              : const Center(child: Text('Tap untuk pilih foto produk')),
        ),
      ),
    );
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
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }
}
