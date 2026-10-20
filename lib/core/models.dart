class Product {
  const Product(
      {required this.id,
      required this.name,
      required this.category,
      required this.price,
      required this.stock,
      this.description = '',
      this.unit = 'piece',
      this.imageUrl = '',
      this.variant = ''});
  final String id, name, category, description, unit, imageUrl, variant;
  final double price;
  final int stock;
  factory Product.fromMap(Map<String, dynamic> m) => Product(
      id: '${m['id']}',
      name: '${m['name']}',
      category: '${m['category_name'] ?? m['category'] ?? 'Others'}',
      price: (m['price'] as num).toDouble(),
      stock: (m['stock_quantity'] as num?)?.toInt() ?? 0,
      description: '${m['description'] ?? ''}',
      unit: '${m['unit'] ?? 'piece'}',
      imageUrl: '${m['image_url'] ?? ''}',
      variant: '${m['variant_name'] ?? ''}');
}
