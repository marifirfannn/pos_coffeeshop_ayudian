import 'package:flutter/material.dart';
import 'package:pos_coffeeshop_ayudian/pages/category_page.dart';
import '../core/session.dart';
import 'kasir_page.dart';
import 'product_page.dart';
import 'transaction_page.dart';
import 'stats_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = Session.role == 'admin';

    print('IS ADMIN = $isAdmin'); // DEBUG

    final pages = isAdmin
        ? [
            const KasirPage(),
            const ProductPage(), // ✅ ADMIN ONLY
            const CategoryPage(),
            const TransactionPage(),
            const StatsPage(),
            const ProfilePage(),
          ]
        : [
            const KasirPage(),
            const TransactionPage(),
            const ProfilePage(),
          ];

    final items = isAdmin
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Kasir'),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory),
              label: 'Produk',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: 'Categorie',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Transaksi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Kasir'),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Transaksi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => index = i),
        items: items,
      ),
    );
  }
}
