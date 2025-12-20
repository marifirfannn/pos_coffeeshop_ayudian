import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/notifier.dart';
import '../core/pos_ui.dart';
import '../services/product_service.dart';
import 'add_product_sheet.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late Future<List<Map<String, dynamic>>> products;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// all | active | inactive
  String _status = 'all';

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
        return Padding(
          padding:
              MediaQuery.of(ctx).viewInsets.add(const EdgeInsets.all(16)),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Stok • ${(product['name'] ?? '-').toString()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: PosTokens.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: PosTokens.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Stok Aktif',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Kalau OFF, stok tidak dihitung otomatis',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: PosTokens.subtext,
                            ),
                          ),
                          value: stockEnabled,
                          onChanged: (v) async {
                            setLocal(() => stockEnabled = v);
                            await ProductService.toggleStockEnabled(id, v);
                            notify(context, 'Stok ${v ? 'aktif' : 'nonaktif'}');
                          },
                        ),
                        const SizedBox(height: 10),
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
                                borderRadius: BorderRadius.circular(16),
                                color: PosTokens.text,
                              ),
                              child: Text(
                                '$stock',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
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
                            await ProductService.setStock(
                              productId: id,
                              stock: val,
                            );
                            setLocal(() => stock = val);
                            notify(context, 'Stok diset ke $val');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('SELESAI'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );

    setState(load);
  }

  void _reset() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _status = 'all';
    });
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> data) {
    final q = _query.trim().toLowerCase();

    Iterable<Map<String, dynamic>> res = data;

    if (q.isNotEmpty) {
      res = res.where((p) => (p['name'] ?? '')
          .toString()
          .toLowerCase()
          .contains(q));
    }

    if (_status == 'active') {
      res = res.where((p) => (p['is_active'] ?? true) == true);
    } else if (_status == 'inactive') {
      res = res.where((p) => (p['is_active'] ?? true) != true);
    }

    return res.toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 860; // tablet+

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
                  crumb: 'Products',
                  actions: [
                    PosIconCircleButton(
                      icon: Icons.add,
                      tooltip: 'Tambah produk',
                      onPressed: openAdd,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search + reset + filter
                Row(
                  children: [
                    Expanded(
                      child: PosSearchField(
                        controller: _searchCtrl,
                        hint: 'Search product...',
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PosIconCircleButton(
                      icon: Icons.close,
                      tooltip: 'Reset',
                      onPressed: _reset,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      PosPill(
                        label: 'All',
                        selected: _status == 'all',
                        onTap: () => setState(() => _status = 'all'),
                      ),
                      const SizedBox(width: 8),
                      PosPill(
                        label: 'Active',
                        selected: _status == 'active',
                        onTap: () => setState(() => _status = 'active'),
                      ),
                      const SizedBox(width: 8),
                      PosPill(
                        label: 'Inactive',
                        selected: _status == 'inactive',
                        onTap: () => setState(() => _status = 'inactive'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: products,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return _ErrorBox(
                          message: 'Error: ${snap.error}',
                          onRetry: () => setState(load),
                        );
                      }

                      final data = snap.data ?? [];
                      if (data.isEmpty) {
                        return _EmptyBox(
                          title: 'Belum ada produk',
                          subtitle: 'Tambahkan produk biar kasir bisa jalan.',
                          buttonText: 'Tambah Produk',
                          onPressed: openAdd,
                        );
                      }

                      final filtered = _filter(data);

                      // KPI quick summary (pakai PosKpiCard kamu)
                      final activeCount = data
                          .where((p) => (p['is_active'] ?? true) == true)
                          .length;
                      final stockOffCount = data
                          .where((p) => (p['stock_enabled'] ?? true) != true)
                          .length;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: PosKpiCard(
                                  icon: Icons.widgets_outlined,
                                  label: 'Total Products',
                                  value: '${data.length}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PosKpiCard(
                                  icon: Icons.check_circle_outline,
                                  label: 'Active',
                                  value: '$activeCount',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PosKpiCard(
                                  icon: Icons.inventory_outlined,
                                  label: 'Stock OFF',
                                  value: '$stockOffCount',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Expanded(
                            child: filtered.isEmpty
                                ? _EmptyBox(
                                    title: 'Tidak ada yang cocok',
                                    subtitle:
                                        'Coba ganti keyword atau ubah filter.',
                                    buttonText: 'Reset',
                                    onPressed: _reset,
                                  )
                                : (isWide
                                    ? _ProductGrid(
                                        data: filtered,
                                        canEdit: user != null,
                                        onEdit: openEdit,
                                        onStock: openStockManager,
                                      )
                                    : _ProductList(
                                        data: filtered,
                                        canEdit: user != null,
                                        onEdit: openEdit,
                                        onStock: openStockManager,
                                      )),
                          ),
                        ],
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

/// ===================
/// LIST VIEW
/// ===================
class _ProductList extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool canEdit;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onStock;

  const _ProductList({
    required this.data,
    required this.canEdit,
    required this.onEdit,
    required this.onStock,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = data[i];
        return _ProductCard(
          product: p,
          canEdit: canEdit,
          onEdit: () => onEdit(p),
          onStock: () => onStock(p),
        );
      },
    );
  }
}

/// ===================
/// GRID VIEW (tablet+)
/// ===================
class _ProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool canEdit;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onStock;

  const _ProductGrid({
    required this.data,
    required this.canEdit,
    required this.onEdit,
    required this.onStock,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    int cols = 2;
    if (w >= 1100) cols = 3;
    if (w >= 1400) cols = 4;

    return GridView.builder(
      itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, i) {
        final p = data[i];
        return _ProductCard(
          product: p,
          canEdit: canEdit,
          onEdit: () => onEdit(p),
          onStock: () => onStock(p),
          compactActions: true,
        );
      },
    );
  }
}

/// ===================
/// PRODUCT CARD
/// ===================
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onStock;
  final bool compactActions;

  const _ProductCard({
    required this.product,
    required this.canEdit,
    required this.onEdit,
    required this.onStock,
    this.compactActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = (product['name'] ?? '-').toString();
    final price = product['price'] ?? 0;

    final isActive = (product['is_active'] ?? true) == true;
    final stockEnabled = (product['stock_enabled'] ?? true) == true;
    final stock = product['stock'] ?? 0;

    final imageUrl = (product['image_url'] ?? '').toString();

    final statusBg = isActive ? const Color(0xFFEAFBF0) : const Color(0xFFF1F5F9);
    final statusBd = isActive ? const Color(0xFF86EFAC) : PosTokens.border;
    final statusTx = isActive ? const Color(0xFF16A34A) : PosTokens.subtext;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTokens.border),
      ),
      child: Row(
        children: [
          _Thumb(imageUrl: imageUrl),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: PosTokens.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusBd),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: statusTx,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Rp $price',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PosTokens.subtext,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stockEnabled ? 'Stock: $stock' : 'Stock: OFF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: stockEnabled
                        ? PosTokens.subtext
                        : const Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ),

          if (canEdit) ...[
            const SizedBox(width: 10),
            if (compactActions)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PosIconCircleButton(
                    icon: Icons.inventory_outlined,
                    tooltip: 'Stock',
                    onPressed: onStock,
                  ),
                  const SizedBox(height: 8),
                  PosIconCircleButton(
                    icon: Icons.edit,
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                ],
              )
            else
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onStock,
                    icon: const Icon(Icons.inventory_outlined, size: 18),
                    label: const Text('Stock'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String imageUrl;

  const _Thumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTokens.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.local_cafe, color: PosTokens.subtext),
              )
            : const Icon(Icons.local_cafe, color: PosTokens.subtext),
      ),
    );
  }
}

/// ===================
/// STATES
/// ===================
class _EmptyBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _EmptyBox({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PosTokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_mall_outlined, size: 34),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: PosTokens.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PosTokens.subtext,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PosTokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 34, color: Color(0xFFEA580C)),
              const SizedBox(height: 10),
              const Text(
                'Gagal memuat data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: PosTokens.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PosTokens.subtext,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
