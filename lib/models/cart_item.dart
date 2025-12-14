class CartItem {
  final String id;
  final String name;
  final int price;
  int qty;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.qty = 1,
  });

  int get subtotal => price * qty;
}
