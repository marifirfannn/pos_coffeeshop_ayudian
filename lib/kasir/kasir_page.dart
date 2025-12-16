import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cart_item.dart';
import '../../services/product_service.dart';
import '../../services/transaction_service.dart';
import '../../core/notifier.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final List<CartItem> cart = [];

  int get total => cart.fold(0, (s, i) => s + i.subtotal);

  void addToCart(Map p) {
    final i = cart.indexWhere((e) => e.id == p['id']);
    setState(() {
      if (i >= 0) {
        cart[i].qty++;
      } else {
        cart.add(
          CartItem(id: p['id'], name: p['name'], price: p['price'], qty: 1),
        );
      }
    });
    notify(context, 'Produk ditambahkan');
  }

  void inc(CartItem c) => setState(() => c.qty++);
  void dec(CartItem c) {
    setState(() {
      if (c.qty > 1) {
        c.qty--;
      } else {
        cart.remove(c);
      }
    });
  }

  void removeItem(CartItem c) => setState(() => cart.remove(c));

  /// ================== CONVERT CART ==================
  List<Map<String, dynamic>> cartItems() {
    return cart
        .map((c) => {'id': c.id, 'price': c.price, 'qty': c.qty})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(title: const Text('Kasir'), centerTitle: true),

      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: openCartMobile,
              icon: const Icon(Icons.shopping_cart),
              label: Text('Cart (${cart.length})'),
            )
          : null,

      body: isMobile
          ? buildProductGrid(crossAxis: 2)
          : Row(
              children: [
                Expanded(child: buildProductGrid(crossAxis: 3)),
                SizedBox(width: 360, child: buildCart()),
              ],
            ),
    );
  }

  /// ================= PRODUK (WITH IMAGE) =================
  Widget buildProductGrid({required int crossAxis}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: FutureBuilder(
        future: ProductService.getProducts(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = (snap.data as List)
              .where((p) => p['is_active'] == true)
              .toList();

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) {
              final p = products[i];

              final String? imageUrl = p['image_url']?.toString();
              final bool hasImage =
                  imageUrl != null && imageUrl.trim().isNotEmpty;

              return InkWell(
                onTap: () => addToCart(p),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey.shade900,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // IMAGE / FALLBACK ICON
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 70,
                          width: 70,
                          child: hasImage
                              ? Image.network(
                                  imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (c, child, loading) {
                                    if (loading == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.local_cafe, size: 28),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.local_cafe, size: 28),
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Text(
                        p['name'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${p['price']}',
                        style: TextStyle(color: Colors.grey.shade400),
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

  /// ================= CART (DESKTOP) =================
  Widget buildCart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(left: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cart',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Cart kosong'))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: cart.map((c) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(c.name),
                          subtitle: Text('Rp ${c.price} x ${c.qty}'),
                          leading: IconButton(
                            tooltip: 'Hapus item',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => removeItem(c),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => dec(c),
                              ),
                              Text('${c.qty}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => inc(c),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          /// TOTAL + CHECKOUT
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('TOTAL', style: TextStyle(color: Colors.grey.shade400)),
                Text(
                  'Rp $total',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: cart.isEmpty ? null : openCheckout,
                  child: const Text('CHECKOUT'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ================= MOBILE CART (REALTIME FIX + DELETE) =================
  void openCartMobile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModal) {
            void incModal(CartItem c) {
              setModal(() => c.qty++);
              setState(() {}); // sync FAB label "Cart (x)"
            }

            void decModal(CartItem c) {
              setModal(() {
                if (c.qty > 1) {
                  c.qty--;
                } else {
                  cart.remove(c);
                }
              });
              setState(() {});
            }

            void deleteModal(CartItem c) {
              setModal(() => cart.remove(c));
              setState(() {});
            }

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border(top: BorderSide(color: Colors.grey.shade800)),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Cart',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: cart.isEmpty
                          ? const Center(child: Text('Cart kosong'))
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              children: cart.map((c) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(c.name),
                                    subtitle: Text('Rp ${c.price} x ${c.qty}'),
                                    leading: IconButton(
                                      tooltip: 'Hapus item',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => deleteModal(c),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: () => decModal(c),
                                        ),
                                        Text('${c.qty}'),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () => incModal(c),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade800),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          Text(
                            'Rp $total',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: cart.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    openCheckout();
                                  },
                            child: const Text('CHECKOUT'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ================= CHECKOUT =================
  void openCheckout() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        String payment = 'cash';

        return StatefulBuilder(
          builder: (_, set) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pembayaran',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: payment,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                    ],
                    onChanged: (v) => set(() => payment = v!),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = Supabase.instance.client.auth.currentUser;

                        if (user == null) {
                          notify(context, 'User belum login', error: true);
                          return;
                        }

                        try {
                          await TransactionService.createTransaction(
                            userId: user.id,
                            total: total,
                            payment: payment,
                            items: cartItems(),
                          );

                          Navigator.pop(context);
                          notify(context, 'Checkout berhasil');
                          setState(() => cart.clear());
                        } catch (e) {
                          debugPrint('CHECKOUT ERROR => $e');
                          notify(context, e.toString(), error: true);
                        }
                      },
                      child: const Text('Bayar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
