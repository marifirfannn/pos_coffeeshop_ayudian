import 'package:flutter/material.dart';
import '../services/categorie_service.dart';
import '../core/notifier.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<List> categories;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    categories = CategoryService.getCategories();
  }

  void add() {
    showDialog(
      context: context,
      builder: (_) => CategoryForm(
        onSaved: () {
          Navigator.pop(context);
          setState(load);
        },
      ),
    );
  }

  void edit(Map c) {
    showDialog(
      context: context,
      builder: (_) => CategoryForm(
        category: c,
        onSaved: () {
          Navigator.pop(context);
          setState(load);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: add)],
      ),
      body: FutureBuilder(
        future: categories,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data!;

          return ListView(
            children: data.map((c) {
              return ListTile(
                title: Text(c['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => edit(c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await CategoryService.deleteCategory(c['id']);
                        notify(context, 'Kategori dihapus');
                        setState(load);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class CategoryForm extends StatefulWidget {
  final Map? category;
  final VoidCallback onSaved;

  const CategoryForm({super.key, this.category, required this.onSaved});

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final name = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      name.text = widget.category!['name'];
    }
  }

  Future<void> save() async {
    if (name.text.isEmpty) {
      notify(context, 'Nama wajib diisi', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      if (widget.category == null) {
        await CategoryService.addCategory(name.text);
        notify(context, 'Kategori ditambahkan');
      } else {
        await CategoryService.updateCategory(widget.category!['id'], name.text);
        notify(context, 'Kategori diupdate');
      }

      widget.onSaved();
    } catch (e) {
      notify(context, 'Gagal simpan kategori', error: true);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.category == null ? 'Tambah Kategori' : 'Edit Kategori',
      ),
      content: TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Nama Kategori'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          onPressed: loading ? null : save,
          child: loading
              ? const CircularProgressIndicator()
              : const Text('SIMPAN'),
        ),
      ],
    );
  }
}
