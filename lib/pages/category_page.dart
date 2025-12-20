import 'package:flutter/material.dart';
import '../services/categorie_service.dart';
import '../core/notifier.dart';
import '../core/pos_ui.dart';

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
      body: PosBackground(
        child: SafeArea(
          child: PosSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosHeaderBar(
                  title: 'Activity',
                  crumb: 'Categories',
                  actions: [
                    PosIconCircleButton(
                      icon: Icons.add,
                      tooltip: 'Tambah kategori',
                      onPressed: add,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search category...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder(
                    future: categories,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(child: Text('Error: ${snap.error}'));
                      }

                      final data = (snap.data as List?) ?? [];
                      if (data.isEmpty) {
                        return const Center(child: Text('Belum ada kategori'));
                      }

                      return ListView.separated(
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = data[i] as Map;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: PosTokens.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5FF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFDAE6FF),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.category,
                                    color: PosTokens.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (c['name'] ?? '-').toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: PosTokens.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: ${(c['id'] ?? '-')}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: PosTokens.subtext,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => edit(c),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Hapus',
                                  onPressed: () => (c),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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
