import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/bohol_address_service.dart';
import '../core/models.dart';
import '../core/services.dart';
import '../core/theme.dart';

String peso(num value) => '₱${value.toStringAsFixed(2)}';

const _constructionCategories = [
  'All',
  'Cement',
  'Blocks',
  'Steel Bars',
  'Wood',
  'Tools',
  'Plumbing',
  'Electrical',
  'Others',
];

Widget _productImage(String url, double size) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF0F4F5),
        child: url.isNotEmpty
            ? Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.inventory_2_outlined, size: 30))
            : const Icon(Icons.inventory_2_outlined, size: 30),
      ),
    );

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.backendConfigured,
    this.onSeeCategories,
  });
  final bool backendConfigured;
  final VoidCallback? onSeeCategories;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  String query = '';
  String selectedCategory = 'All';
  late final Stream<List<Product>> _productsStream = Backend.productsStream();
  @override
  Widget build(BuildContext context) {
    final user = widget.backendConfigured ? Backend.db.auth.currentUser : null;
    final name = user?.userMetadata?['full_name'] ?? 'Builder';
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(children: [
            Image.asset(
              'assets/buildhive_icon.png',
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('BUILDHIVE',
                      style: TextStyle(
                        color: hiveBlack,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                    Text('CONSTRUCTION HARDWARE',
                      style: TextStyle(
                        color: hiveMuted,
                        fontSize: 9,
                        letterSpacing: 1.1)),
                ])),
            IconButton.filledTonal(
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: hiveBlack,
                    fixedSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SupportScreen())),
                icon: const Icon(Icons.support_agent_outlined)),
          ]),
            const SizedBox(height: 18),
          Text('Good day, $name!',
              style: const TextStyle(
                fontSize: 23, height: 1.15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Build more. Deliver faster.',
              style: TextStyle(color: hiveMuted, fontSize: 15)),
          const SizedBox(height: 14),
          TextField(
              controller: search,
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search cement, tools, steel bars...')),
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: hiveBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('BUILDHIVE SELECT',
                          style: TextStyle(
                              color: hiveYellow,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 12),
                      Text('Build with confidence',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.2,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('Reliable supplies for every project.',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4)),
                    ])),
                const SizedBox(width: 12),
                Container(
                    width: 72,
                    height: 88,
                    decoration: BoxDecoration(
                        color: hiveYellow,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.construction_rounded,
                        color: hiveBlack, size: 42)),
              ])),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text('Shop by Category',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: widget.onSeeCategories,
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _constructionCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _constructionCategories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: selectedCategory == category,
                  onSelected: (_) =>
                      setState(() => selectedCategory = category),
                );
              },
            ),
          ),
          const SizedBox(height: 26),
          const Text('Popular Products',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (!widget.backendConfigured)
            const _Notice(
                text:
                    'Connect Supabase using the setup instructions to load live products.'),
          if (widget.backendConfigured)
            StreamBuilder<List<Product>>(
                stream: _productsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return const _Notice(
                        text:
                            'Could not load products. Check Supabase configuration and RLS policies.');
                  }
                  final items = (snapshot.data ?? []).where((product) {
                    final matchesCategory = selectedCategory == 'All' ||
                        product.category == selectedCategory;
                    final matchesQuery = query.isEmpty ||
                        product.name
                            .toLowerCase()
                            .contains(query.toLowerCase());
                    return matchesCategory && matchesQuery;
                  }).toList();
                  if (items.isEmpty) {
                    return const _Notice(
                        text:
                            'No products found yet. Add products from the admin panel.');
                  }
                    return _ProductGrid(products: items);
                }),
        ]);
  }
}

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, this.initialCategory = 'All'});
  final String initialCategory;
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late String category = widget.initialCategory;
  late final Stream<List<Product>> _productsStream = Backend.productsStream();
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Categories',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Find the right materials for your project.',
            style: TextStyle(color: hiveMuted, fontSize: 14)),
        const SizedBox(height: 14),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _constructionCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _constructionCategories[index];
              return ChoiceChip(
                label: Text(item),
                selected: category == item,
                onSelected: (_) => setState(() => category = item),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (!Backend.isConfigured)
          const _Notice(
              text: 'Connect Supabase to browse live products and categories.'),
        if (Backend.isConfigured)
          StreamBuilder<List<Product>>(
              stream: _productsStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return const _Notice(
                      text:
                          'Connect Supabase and verify catalog read policies.');
                }
                final products = (snap.data ?? [])
                    .where((product) =>
                        category == 'All' || product.category == category)
                    .toList();
                if (products.isEmpty) {
                  return const _Notice(
                      text: 'No active products in this category yet.');
                }
                return _ProductGrid(products: products);
              }),
      ]);
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 238,
        ),
        itemBuilder: (context, index) => ProductTile(product: products[index]),
      );
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: _productImage(product.imageUrl, double.infinity),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${peso(product.price)} / ${product.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: hiveYellow,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.stock > 0 ? 'In stock' : 'Out of stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: hiveMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Add to cart',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                          width: 34, height: 34),
                      iconSize: 18,
                      style: IconButton.styleFrom(
                        backgroundColor: hiveYellow,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: product.stock < 1
                          ? null
                          : () => CartStore.add(product),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class CartStore {
  static final Map<String, Map<String, dynamic>> items = {};
  static bool add(Product p, {int quantity = 1}) {
    final existing = items[p.id];
    final currentQuantity = existing == null ? 0 : existing['qty'] as int;
    if (quantity < 1 || currentQuantity + quantity > p.stock) return false;

    if (existing == null) {
      items[p.id] = {'product': p, 'qty': quantity};
    } else {
      existing['qty'] = currentQuantity + quantity;
    }
    return true;
  }

  static double get subtotal => items.values.fold(
      0,
      (sum, row) =>
          sum + (row['product'] as Product).price * (row['qty'] as int));
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    this.stockUpdates,
  });
  final Product product;
  final Stream<Product?>? stockUpdates;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int qty = 1;
  late final Stream<Product?>? _stockUpdates;

  @override
  void initState() {
    super.initState();
    _stockUpdates = widget.stockUpdates ??
        (Backend.isConfigured
            ? Backend.productStream(widget.product.id)
            : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: StreamBuilder<Product?>(
            stream: _stockUpdates,
            initialData: widget.product,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                    child: _Notice(text: 'Unable to refresh product stock.'));
              }
              if (_stockUpdates != null &&
                  snapshot.connectionState != ConnectionState.waiting &&
                  snapshot.data == null) {
                return const Center(
                    child:
                        _Notice(text: 'This product is no longer available.'));
              }
              final p = snapshot.data ?? widget.product;
              final selectedQuantity =
                  p.stock > 0 ? qty.clamp(1, p.stock).toInt() : 0;
              return ListView(padding: const EdgeInsets.all(20), children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                        height: 210,
                        width: double.infinity,
                        color: const Color(0xFFF0F4F5),
                        child: widget.product.imageUrl.isNotEmpty
                            ? Image.network(widget.product.imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 100))
                            : const Icon(Icons.inventory_2_outlined,
                                size: 100))),
                const SizedBox(height: 20),
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w900)),
                Row(children: [
                  Expanded(
                      child: Text(p.category,
                          style: const TextStyle(color: hiveMuted))),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                          color: p.stock > 0
                              ? const Color(0xFFE7F2EC)
                              : const Color(0xFFFCE8E6),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            p.stock > 0
                                ? Icons.inventory_2_outlined
                                : Icons.remove_shopping_cart_outlined,
                            size: 16,
                            color: p.stock > 0 ? hiveGreen : Colors.redAccent),
                        const SizedBox(width: 6),
                        Text(
                            p.stock > 0
                                ? 'Stock: ${p.stock} ${p.unit}'
                                : 'Out of stock',
                            style: TextStyle(
                                color:
                                    p.stock > 0 ? hiveGreen : Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ])),
                ]),
                const SizedBox(height: 8),
                Text(peso(p.price),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Text(p.description.isEmpty
                    ? 'Quality construction material for residential and commercial projects.'
                    : p.description),
                const SizedBox(height: 20),
                Row(children: [
                  IconButton(
                      onPressed: selectedQuantity > 1
                          ? () => setState(() => qty = selectedQuantity - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('$selectedQuantity',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  IconButton(
                      onPressed: selectedQuantity < p.stock
                          ? () => setState(() => qty = selectedQuantity + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline)),
                  const Spacer(),
                  Text('Total ${peso(p.price * selectedQuantity)}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: p.stock < 1
                              ? null
                              : () {
                                  final added = CartStore.add(p,
                                      quantity: selectedQuantity);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(added
                                              ? 'Added to cart'
                                              : 'This quantity exceeds available stock.')));
                                },
                          icon: const Icon(Icons.add_shopping_cart_outlined),
                          label: const Text('Add to Cart'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: p.stock < 1
                              ? null
                              : () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => CheckoutScreen(
                                          buyNowProduct: p,
                                          buyNowQuantity: selectedQuantity))),
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text('Buy Now'))),
                ]),
              ]);
            }));
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final Stream<List<Product>>? _stockUpdates =
      Backend.isConfigured ? Backend.productsStream() : null;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
      stream: _stockUpdates,
      builder: (context, snapshot) {
        final liveProducts = {
          for (final product in snapshot.data ?? <Product>[])
            product.id: product,
        };
        final inventoryReady = !Backend.isConfigured || snapshot.hasData;
        final inventoryError = Backend.isConfigured && snapshot.hasError;
        final hasUnavailableItems = CartStore.items.entries.any((entry) {
          final cachedProduct = entry.value['product'] as Product;
          final liveProduct = liveProducts[cachedProduct.id];
          final quantity = entry.value['qty'] as int;
          if (!Backend.isConfigured) return quantity > cachedProduct.stock;
          return !inventoryReady ||
              liveProduct == null ||
              quantity > liveProduct.stock;
        });
        final subtotal = CartStore.items.entries.fold<double>(0, (sum, entry) {
          final cachedProduct = entry.value['product'] as Product;
          final product = liveProducts[cachedProduct.id] ?? cachedProduct;
          return sum + product.price * (entry.value['qty'] as int);
        });

        return ListView(padding: const EdgeInsets.all(18), children: [
          const Text('Your Cart',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Review your materials before checkout.',
              style: TextStyle(color: hiveMuted, fontSize: 14)),
          const SizedBox(height: 18),
          if (Backend.isConfigured &&
              snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (inventoryError)
            const _Notice(
                text:
                    'Could not verify live stock. Try again before checkout.'),
          if (CartStore.items.isEmpty)
            const _Notice(
                text:
                    'Your cart is empty. Browse categories and add products.'),
          ...CartStore.items.entries.map((entry) {
            final cachedProduct = entry.value['product'] as Product;
            final product = liveProducts[cachedProduct.id] ?? cachedProduct;
            final quantity = entry.value['qty'] as int;
            final missing = Backend.isConfigured &&
                inventoryReady &&
                !liveProducts.containsKey(cachedProduct.id);
            return Card(
                child: ListTile(
                    title: Text(product.name),
                    subtitle: Text(missing
                        ? 'No longer available'
                        : '${peso(product.price)} × $quantity · Stock: ${product.stock} ${product.unit}'),
                    isThreeLine: missing || quantity > product.stock,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          onPressed: () => setState(() {
                                if (quantity <= 1) {
                                  CartStore.items.remove(entry.key);
                                } else {
                                  entry.value['qty'] = quantity - 1;
                                }
                              }),
                          icon: const Icon(Icons.remove_circle_outline)),
                      Text('$quantity'),
                      IconButton(
                          onPressed: quantity < product.stock
                              ? () => setState(
                                  () => entry.value['qty'] = quantity + 1)
                              : null,
                          icon: const Icon(Icons.add_circle_outline)),
                    ])));
          }),
          if (hasUnavailableItems)
            const _Notice(
                text:
                    'Update quantities to match the live stock before checkout.'),
          if (CartStore.items.isNotEmpty) ...[
            const Divider(),
            _totalRow('Subtotal', peso(subtotal)),
            _totalRow('Delivery Fee', 'Calculated at checkout'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: hasUnavailableItems || inventoryError
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CheckoutScreen())),
                child: const Text('Proceed to Checkout')),
          ],
        ]);
      });
}

Widget _totalRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]));

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.buyNowProduct,
    this.buyNowQuantity = 1,
  });
  final Product? buyNowProduct;
  final int buyNowQuantity;

  List<Map<String, dynamic>> get checkoutItems {
    final product = buyNowProduct;
    if (product == null) return CartStore.items.values.toList();
    return [
      {'product': product, 'qty': buyNowQuantity},
    ];
  }

  double get subtotal {
    final product = buyNowProduct;
    return product == null
        ? CartStore.subtotal
        : product.price * buyNowQuantity;
  }

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _draftPrefix = 'buildhive_checkout_';

  static String _newCheckoutRequestId() {
    final random = math.Random.secure();
    final hex = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  final name = TextEditingController();
  final phone = TextEditingController();
  final landmark = TextEditingController();
  final notes = TextEditingController();
  BoholArea? _municipality;
  BoholArea? _barangay;
  List<BoholArea> _barangays = const [];
  String? _locationError;
  bool _loadingBarangays = false;
  bool _restoringDraft = true;
  Timer? _draftTimer;
  String payment = 'cod';
  bool busy = false;
  late final List<Map<String, dynamic>> _checkoutItems;
  late final double _checkoutSubtotal;
  String _checkoutRequestId = _newCheckoutRequestId();
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _checkoutItems = widget.checkoutItems.map(Map<String, dynamic>.of).toList();
    _checkoutSubtotal = widget.subtotal;
    unawaited(_restoreCheckoutDraft());
  }

  Future<void> _restoreCheckoutDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      name.text = prefs.getString('${_draftPrefix}name') ?? '';
      phone.text = prefs.getString('${_draftPrefix}phone') ?? '';
      landmark.text = prefs.getString('${_draftPrefix}landmark') ?? '';
      notes.text = prefs.getString('${_draftPrefix}notes') ?? '';

      final municipalityCode =
          prefs.getString('${_draftPrefix}municipality_code');
      if (municipalityCode != null) {
        for (final area in BoholAddressService.municipalities) {
          if (area.code == municipalityCode) {
            await _selectMunicipality(
              area,
              savedBarangayCode:
                  prefs.getString('${_draftPrefix}barangay_code'),
              saveDraft: false,
            );
            break;
          }
        }
      }
    } catch (_) {
      // Checkout remains available if saved preferences cannot be read.
    } finally {
      if (mounted) setState(() => _restoringDraft = false);
    }
  }

  Future<void> _selectMunicipality(
    BoholArea? area, {
    String? savedBarangayCode,
    bool saveDraft = true,
  }) async {
    setState(() {
      _municipality = area;
      _barangay = null;
      _barangays = const [];
      _loadingBarangays = area != null;
      _locationError = null;
    });

    if (area != null) {
      try {
        final barangays = await BoholAddressService.barangaysFor(area);
        if (!mounted) return;
        setState(() {
          _barangays = barangays;
          _barangay = barangays.cast<BoholArea?>().firstWhere(
                (barangay) => barangay?.code == savedBarangayCode,
                orElse: () => null,
              );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _locationError = 'Could not load barangays. Check your connection.';
        });
      } finally {
        if (mounted) setState(() => _loadingBarangays = false);
      }
    }

    if (saveDraft) _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    if (_restoringDraft) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_saveCheckoutDraft()),
    );
  }

  Future<void> _saveCheckoutDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_draftPrefix}name', name.text.trim());
      await prefs.setString('${_draftPrefix}phone', phone.text.trim());
      await prefs.setString(
          '${_draftPrefix}municipality_code', _municipality?.code ?? '');
      await prefs.setString(
          '${_draftPrefix}barangay_code', _barangay?.code ?? '');
      await prefs.setString('${_draftPrefix}landmark', landmark.text.trim());
      await prefs.setString('${_draftPrefix}notes', notes.text.trim());
    } catch (_) {
      // The order still saves these details even if local draft storage fails.
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    name.dispose();
    phone.dispose();
    landmark.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Delivery Address',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(
            key: const ValueKey('checkout-name'),
            controller: name,
            onChanged: (_) => _scheduleDraftSave(),
            decoration: const InputDecoration(labelText: 'Full name')),
        const SizedBox(height: 10),
        TextField(
            key: const ValueKey('checkout-phone'),
            controller: phone,
            onChanged: (_) => _scheduleDraftSave(),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number')),
        const SizedBox(height: 10),
        DropdownButtonFormField<BoholArea>(
          key: ValueKey(_municipality?.code ?? 'bohol-municipality'),
          initialValue: _municipality,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Bohol municipality or city',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: BoholAddressService.municipalities
              .map((area) => DropdownMenuItem(
                    value: area,
                    child: Text(area.name),
                  ))
              .toList(),
          onChanged: _restoringDraft
              ? null
              : (area) => unawaited(_selectMunicipality(area)),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<BoholArea>(
          key: ValueKey(_barangay?.code ??
              'bohol-barangay-${_municipality?.code ?? 'none'}'),
          initialValue: _barangay,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Barangay',
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: _loadingBarangays
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          items: _barangays
              .map((area) => DropdownMenuItem(
                    value: area,
                    child: Text(area.name),
                  ))
              .toList(),
          onChanged:
              _municipality == null || _loadingBarangays || _barangays.isEmpty
                  ? null
                  : (area) {
                      setState(() => _barangay = area);
                      _scheduleDraftSave();
                    },
        ),
        if (_locationError != null) ...[
          const SizedBox(height: 6),
          Text(_locationError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          TextButton.icon(
            onPressed: _municipality == null
                ? null
                : () => unawaited(_selectMunicipality(_municipality)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry barangay list'),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('checkout-landmark'),
          controller: landmark,
          onChanged: (_) => _scheduleDraftSave(),
          decoration: const InputDecoration(
            labelText: 'Landmark (optional)',
            prefixIcon: Icon(Icons.near_me_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
            key: const ValueKey('checkout-notes'),
            controller: notes,
            onChanged: (_) => _scheduleDraftSave(),
            decoration:
                const InputDecoration(labelText: 'Delivery notes (optional)')),
        const SizedBox(height: 20),
        const Text('Payment Method',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        RadioGroup<String>(
          groupValue: payment,
          onChanged: (value) {
            if (_pendingOrderId == null && value != null) {
              setState(() => payment = value);
            }
          },
          child: const Column(children: [
            RadioListTile<String>(
                value: 'cod',
                title: Text('Cash on Delivery'),
                subtitle: Text('Pay when your order arrives')),
            RadioListTile<String>(
                value: 'paymongo',
                title: Text('PayMongo'),
                subtitle: Text('Secure online payment')),
          ]),
        ),
        const SizedBox(height: 10),
        _totalRow('Subtotal', peso(_checkoutSubtotal)),
        _totalRow('Delivery Fee', 'Free'),
        _totalRow('Total', peso(_checkoutSubtotal)),
        const SizedBox(height: 14),
        ElevatedButton(
            onPressed: busy
                ? null
                : () async {
                    if (name.text.trim().isEmpty ||
                        phone.text.trim().isEmpty ||
                        _municipality == null ||
                        _barangay == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Complete your name, phone, municipality and barangay.')));
                      return;
                    }
                    if (!Backend.isConfigured ||
                        Backend.db.auth.currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Please sign in before placing an order.')));
                      return;
                    }
                    setState(() => busy = true);
                    try {
                      if (_pendingOrderId == null) await _saveCheckoutDraft();
                      final isNewOrder = _pendingOrderId == null;
                      final orderId = _pendingOrderId ?? await Backend.placeOrder(
                        checkoutRequestId: _checkoutRequestId,
                        paymentMethod: payment,
                        deliveryName: name.text.trim(),
                        deliveryPhone: phone.text.trim(),
                        municipalityCode: _municipality!.code,
                        municipality: _municipality!.name,
                        barangayCode: _barangay!.code,
                        barangay: _barangay!.name,
                        landmark: landmark.text.trim(),
                        deliveryNotes: notes.text.trim(),
                        items: _checkoutItems.map((row) {
                          final product = row['product'] as Product;
                          return {
                            'product_id': product.id,
                            'quantity': row['qty'] as int,
                          };
                        }).toList(),
                      );
                      _pendingOrderId = orderId;
                      if (isNewOrder && widget.buyNowProduct == null) {
                        CartStore.items.clear();
                      }
                      if (payment == 'paymongo') {
                        final response = await Backend.db.functions.invoke(
                            'create-paymongo-checkout',
                            body: {'order_id': orderId});
                        final url = response.data['checkout_url'] as String?;
                        if (url == null ||
                            Uri.tryParse(url)?.hasScheme != true) {
                          throw Exception(
                              'A valid checkout URL was not returned.');
                        }
                        final opened = await launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication);
                        if (!opened && context.mounted) {
                          await showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                      title: const Text(
                                          'Continue to secure payment'),
                                      content: SelectableText(url),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext),
                                            child: const Text('Close'))
                                      ]));
                        }
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Order created. View it in My Orders.')));
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        final message = e.toString();
                        final checkoutExpired = _pendingOrderId != null &&
                            (message.toLowerCase().contains('checkout expired') ||
                                message.toLowerCase().contains('no longer payable'));
                        if (checkoutExpired) {
                          _pendingOrderId = null;
                          _checkoutRequestId = _newCheckoutRequestId();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(checkoutExpired
                                    ? 'Checkout expired. Tap Place Order to start a new checkout.'
                                    : 'Checkout failed: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Processing...' : 'Place Order')),
      ]));
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Backend.isConfigured ? Backend.db.auth.currentUser : null;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Orders',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text('Your purchases, from checkout to delivery.',
                style: TextStyle(color: hiveMuted, fontSize: 14)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F2EB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 8, color: hiveGreen),
            SizedBox(width: 6),
            Text('LIVE',
                style: TextStyle(
                    color: hiveGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      if (user == null) const _Notice(text: 'Sign in to view your orders.'),
      if (user != null)
        StreamBuilder<List<Map<String, dynamic>>>(
            stream: Backend.customerOrdersStream(user.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 44),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return const _Notice(
                    text:
                        'Unable to load live orders. Verify order access policies and Realtime setup.');
              }
              if ((snap.data ?? []).isEmpty) {
                return const _Notice(text: 'No orders yet.');
              }
              final orders = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('${orders.length} recent orders',
                        style: const TextStyle(
                            color: hiveMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                  ...orders.map((order) => Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _OrderPurchaseCard(
                          order: order,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackingScreen(order: order),
                            ),
                          ),
                        ),
                      )),
                ],
              );
            }),
    ]);
  }
}

class _OrderPurchaseCard extends StatelessWidget {
  const _OrderPurchaseCard({required this.order, required this.onTap});

  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = order['id']?.toString() ?? '';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    final status = order['status']?.toString() ?? 'pending';
    final normalizedStatus = status.toLowerCase().replaceAll(' ', '_');
    final paymentMethod =
      order['payment_method']?.toString().toLowerCase() ?? 'payment pending';
    final paymentStatus =
      order['payment_status']?.toString().toLowerCase() ?? 'pending';
    final badgeStatus = paymentMethod == 'paymongo' ? paymentStatus : status;
    final normalizedBadgeStatus =
      badgeStatus.toLowerCase().replaceAll(' ', '_');
    final isCancelled = const {'cancelled', 'canceled', 'rejected', 'failed'}
        .contains(normalizedStatus);
    final isComplete = const {'delivered', 'complete', 'completed'}
        .contains(normalizedStatus);
    final statusColor = paymentMethod == 'paymongo'
      ? paymentStatus == 'paid'
        ? hiveGreen
        : const Color(0xFF946200)
      : isCancelled
        ? const Color(0xFFB54747)
        : isComplete
          ? hiveGreen
          : normalizedStatus == 'pending'
            ? const Color(0xFF946200)
            : const Color(0xFF315F8A);
    final placedAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final destinationParts = [
      order['delivery_barangay']?.toString(),
      order['delivery_municipality']?.toString(),
      if (order['delivery_barangay'] != null ||
          order['delivery_municipality'] != null)
        'Bohol',
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    final destination = destinationParts.isNotEmpty
        ? destinationParts.join(', ')
        : order['delivery_address']?.toString() ?? 'Delivery address unavailable';
    final paymentLabel = paymentMethod == 'cod'
        ? 'Cash on delivery'
        : paymentMethod == 'paymongo'
            ? 'Online payment'
            : paymentMethod;
    final paymentStatusLabel = paymentStatus == 'paid'
      ? 'Paid'
      : paymentStatus.replaceAll('_', ' ');
    final total = (order['total'] as num?)?.toDouble() ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 12, 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1C5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: hiveBlack, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Order #$shortId',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    placedAt == null
                        ? 'Placed date unavailable'
                        : DateFormat('MMM d, yyyy · h:mm a')
                            .format(placedAt.toLocal()),
                    style: const TextStyle(color: hiveMuted, fontSize: 12),
                  ),
                  if (paymentMethod == 'paymongo')
                    Text('Order: ${status.replaceAll('_', ' ')}',
                        style: const TextStyle(color: hiveMuted, fontSize: 12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  normalizedBadgeStatus.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: hiveLine),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.location_on_outlined,
                    size: 17, color: hiveMuted),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(destination,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: hiveBlack)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: hiveMuted, size: 21),
            ]),
            const SizedBox(height: 11),
            Row(children: [
              const Icon(Icons.payments_outlined, size: 16, color: hiveMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(paymentLabel,
                      style: const TextStyle(fontSize: 12, color: hiveMuted)),
                  const SizedBox(height: 3),
                  Text('Payment: $paymentStatusLabel',
                      style: TextStyle(
                          fontSize: 12,
                          color: paymentStatus == 'paid'
                              ? hiveGreen
                              : const Color(0xFF946200),
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              Text(peso(total),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.order});
  final Map<String, dynamic> order;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final Future<List<Map<String, dynamic>>> _orderItems = _loadOrderItems();
  String? _updatedStatus;
  Map<String, dynamic>? _liveOrder;
  StreamSubscription<List<Map<String, dynamic>>>? _orderSubscription;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    final user = Backend.isConfigured ? Backend.db.auth.currentUser : null;
    if (user != null) {
      _orderSubscription = Backend.db
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('id', widget.order['id'].toString())
          .eq('customer_id', user.id)
          .listen((rows) {
        if (mounted && rows.isNotEmpty) {
          setState(() => _liveOrder = rows.first);
        }
      });
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadOrderItems() {
    if (!Backend.isConfigured) return Future.value(const []);
    return Backend.db
        .from('order_items')
        .select('product_name, quantity, unit_price')
        .eq('order_id', widget.order['id']);
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this COD order?'),
        content: const Text(
            'The order will be cancelled and its items returned to stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await Backend.db.rpc('cancel_cod_order', params: {
        'p_order_id': widget.order['id'],
      });
      if (!mounted) return;
      setState(() => _updatedStatus = 'cancelled');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled and stock restored.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not cancel. The order may already be processing.')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _displayStatus(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  int _statusStep(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'pending':
      case 'received':
      case 'order_received':
        return 0;
      case 'confirmed':
      case 'processing':
      case 'preparing':
      case 'preparing_order':
        return 1;
      case 'shipped':
      case 'out_for_delivery':
      case 'delivering':
        return 2;
      case 'delivered':
      case 'complete':
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  bool _isCancelled(String status) => const {
        'cancelled',
        'canceled',
        'rejected',
        'failed'
      }.contains(status.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final order = _liveOrder ?? widget.order;
    final status = _updatedStatus ?? order['status']?.toString() ?? 'pending';
    final cancelled = _isCancelled(status);
    final currentStep = _statusStep(status);
    final id = order['id']?.toString() ?? '';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    final placedAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final addressParts = [
      order['delivery_barangay']?.toString(),
      order['delivery_municipality']?.toString(),
      if (order['delivery_barangay'] == null &&
          order['delivery_municipality'] == null)
        order['delivery_address']?.toString(),
      'Bohol',
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    final address = addressParts.join(', ');
    final subtotal = order['subtotal'] as num? ?? 0;
    final deliveryFee = order['delivery_fee'] as num? ?? 0;
    final total = order['total'] as num? ?? subtotal + deliveryFee;
    final paymentMethod = order['payment_method']?.toString() ?? 'unknown';
    final paymentStatus = order['payment_status']?.toString() ?? 'unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: hiveBlack,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cancelled ? Colors.redAccent : hiveYellow,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    cancelled
                        ? Icons.cancel_outlined
                        : currentStep == 3
                            ? Icons.task_alt_rounded
                            : Icons.local_shipping_outlined,
                    color: cancelled ? Colors.white : hiveBlack,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORDER STATUS',
                          style: TextStyle(
                              color: hiveYellow,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(_displayStatus(status),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text('Order #$shortId',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            if (cancelled)
              const _TrackingNotice(
                  icon: Icons.info_outline_rounded,
                  text: 'This order is no longer being processed.'),
            if (!cancelled) _OrderProgress(currentStep: currentStep),
            const SizedBox(height: 16),
            _TrackingSection(
              title: 'Delivery details',
              icon: Icons.location_on_outlined,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _trackingInfoRow(
                        'Recipient', order['delivery_name']?.toString()),
                    _trackingInfoRow(
                        'Phone', order['delivery_phone']?.toString()),
                    _trackingInfoRow('Address', address),
                    if ((order['delivery_landmark']?.toString() ?? '')
                        .isNotEmpty)
                      _trackingInfoRow(
                          'Landmark', order['delivery_landmark'].toString()),
                    if ((order['delivery_notes']?.toString() ?? '').isNotEmpty)
                      _trackingInfoRow(
                          'Delivery note', order['delivery_notes'].toString()),
                  ]),
            ),
            const SizedBox(height: 12),
            _TrackingSection(
              title: 'Payment summary',
              icon: Icons.receipt_long_outlined,
              child: Column(children: [
                _trackingInfoRow('Method', _displayStatus(paymentMethod)),
                _trackingInfoRow(
                    'Payment status', _displayStatus(paymentStatus)),
                _trackingInfoRow('Subtotal', peso(subtotal)),
                _trackingInfoRow('Delivery fee', peso(deliveryFee)),
                const Divider(height: 20),
                _trackingInfoRow('Total paid / due', peso(total), bold: true),
              ]),
            ),
            if (paymentMethod.toLowerCase() == 'cod' &&
                status.toLowerCase() == 'pending' &&
                Backend.isConfigured) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cancelling ? null : _cancelOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                icon: _cancelling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: Text(_cancelling ? 'Cancelling...' : 'Cancel Order'),
              ),
            ],
            if (placedAt != null) ...[
              const SizedBox(height: 12),
              _TrackingSection(
                title: 'Order placed',
                icon: Icons.schedule_rounded,
                child: Text(
                    DateFormat.yMMMMd().add_jm().format(placedAt.toLocal()),
                    style: const TextStyle(color: hiveMuted)),
              ),
            ],
            const SizedBox(height: 12),
            _TrackingSection(
              title: 'Items',
              icon: Icons.inventory_2_outlined,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _orderItems,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text('Order items could not be loaded.');
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return const Text('No item details are available.');
                  }
                  return Column(
                    children: items.map((item) {
                      final quantity = item['quantity'] as num? ?? 0;
                      final unitPrice = item['unit_price'] as num? ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                                item['product_name']?.toString() ?? 'Product'),
                          ),
                          Text('${quantity.toInt()} × ${peso(unitPrice)}',
                              style: const TextStyle(
                                  color: hiveMuted,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const _TrackingNotice(
                icon: Icons.map_outlined,
                text:
                    'Live driver location is unavailable until a driver-tracking provider is connected.'),
          ]),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.currentStep});
  final int currentStep;

  static const _steps = [
    ('Order received', Icons.receipt_long_outlined),
    ('Preparing order', Icons.inventory_2_outlined),
    ('Out for delivery', Icons.local_shipping_outlined),
    ('Delivered', Icons.task_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) => _TrackingSection(
        title: 'Progress',
        icon: Icons.timeline_rounded,
        child: Column(
          children: List.generate(_steps.length, (index) {
            final complete = index < currentStep;
            final active = index == currentStep;
            final color = complete
                ? hiveGreen
                : active
                    ? hiveBlack
                    : hiveMuted.withValues(alpha: .45);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 28,
                child: Column(children: [
                  Icon(complete ? Icons.check_circle : _steps[index].$2,
                      size: 21, color: complete ? hiveGreen : color),
                  if (index < _steps.length - 1)
                    Container(
                        width: 2,
                        height: 25,
                        color: complete
                            ? hiveGreen.withValues(alpha: .55)
                            : hiveLine),
                ]),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_steps[index].$1,
                    style: TextStyle(
                        color: color,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w500)),
              ),
            ]);
          }),
        ),
      );
}

class _TrackingSection extends StatelessWidget {
  const _TrackingSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 19, color: hiveGreen),
                const SizedBox(width: 9),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

Widget _trackingInfoRow(String label, String? value, {bool bold = false}) {
  final displayValue = value?.trim();
  if (displayValue == null || displayValue.isEmpty) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 104,
        child: Text(label, style: const TextStyle(color: hiveMuted)),
      ),
      Expanded(
        child: Text(displayValue,
            textAlign: TextAlign.end,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ),
    ]),
  );
}

class _TrackingNotice extends StatelessWidget {
  const _TrackingNotice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: hiveLine)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: hiveMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: hiveMuted, fontSize: 13, height: 1.4))),
        ]),
      );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onSignedOut});
  final VoidCallback? onSignedOut;
  @override
  Widget build(BuildContext context) {
    final user = Backend.isConfigured ? Backend.db.auth.currentUser : null;
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Profile',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 22),
      const CircleAvatar(
          radius: 34,
          backgroundColor: hiveYellow,
          child: Icon(Icons.person, size: 38, color: hiveBlack)),
      const SizedBox(height: 8),
      Center(
          child: Text(user?.email ?? 'Guest account',
              style: const TextStyle(fontWeight: FontWeight.w800))),
      const SizedBox(height: 20),
      _menu(context, Icons.location_on_outlined, 'My Addresses',
          const AddressScreen()),
      _menu(context, Icons.credit_card_outlined, 'Payment Methods',
          const PaymentMethodsScreen()),
      _menu(context, Icons.receipt_long_outlined, 'My Orders',
          const OrdersScreen()),
      _menu(context, Icons.support_agent_outlined, 'Support / Help',
          const SupportScreen()),
      _menu(
          context, Icons.settings_outlined, 'Settings', const SettingsScreen()),
      if (user == null)
        ElevatedButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AuthScreen())),
            child: const Text('Login / Register'))
      else
        OutlinedButton(
            onPressed: () async {
              await Backend.db.auth.signOut();
              if (context.mounted) onSignedOut?.call();
            },
            child: const Text('Sign Out')),
    ]);
  }
}

Widget _menu(BuildContext context, IconData icon, String title, Widget page) =>
    Card(
        child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => page))));

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});
  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final label = TextEditingController(text: 'Home'),
      name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Add Address')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        TextField(
            controller: label,
            decoration: const InputDecoration(labelText: 'Address label')),
        const SizedBox(height: 10),
        TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name')),
        const SizedBox(height: 10),
        TextField(
            controller: phone,
            decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 10),
        TextField(
            controller: address,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Complete address')),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: () async {
              if (!Backend.isConfigured ||
                  Backend.db.auth.currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Sign in to save an address.')));
                return;
              }
              try {
                final client = Backend.db;
                final user = client.auth.currentUser!;
                await client.from('addresses').insert({
                  'user_id': user.id,
                  'label': label.text,
                  'recipient_name': name.text,
                  'phone': phone.text,
                  'address_line': address.text
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address saved.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save: $e')));
                }
              }
            },
            child: const Text('Save Address')),
      ]));
}

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: const Padding(
          padding: EdgeInsets.all(18),
          child: _Notice(
              text:
                  'Online payment methods are securely handled by PayMongo checkout. Card details should not be stored in BUILDHIVE database.')));
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(padding: const EdgeInsets.all(18), children: const [
        ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('FAQs'),
            subtitle: Text(
                'How do I place an order? Browse products, add to cart, then complete checkout.')),
        ListTile(
            leading: Icon(Icons.local_shipping_outlined),
            title: Text('Delivery'),
            subtitle: Text(
                'Delivery estimates depend on your service area and order status.')),
        ListTile(
            leading: Icon(Icons.payment_outlined),
            title: Text('Payments'),
            subtitle: Text(
                'PayMongo payments are confirmed by a verified server webhook.')),
        ListTile(
            leading: Icon(Icons.contact_support_outlined),
            title: Text('Contact Us'),
            subtitle: Text(
                'Add your official customer support email and phone before launch.')),
        ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('Terms & Privacy'),
            subtitle: Text(
                'Publish your approved policies before accepting orders.')),
      ]));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: const [
        ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Change password'),
            subtitle: Text('Use Supabase password reset flow.')),
        ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About BUILDHIVE'),
            subtitle: Text('Build More. Deliver Faster.')),
      ]));
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.requiredAuth = false,
    this.backendInitializationPending = false,
    this.backendInitializationFailed = false,
    this.backendInitializationError,
    this.onAuthenticated,
  });
  final bool? requiredAuth;
  final bool backendInitializationPending;
  final bool backendInitializationFailed;
  final String? backendInitializationError;
  final VoidCallback? onAuthenticated;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      fullName = TextEditingController(),
      phone = TextEditingController();
  bool register = false, busy = false, visible = false;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(register ? 'Create Your Account' : 'Welcome Back')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.requiredAuth ?? false)
          const _Notice(text: 'Sign in or create an account to continue.'),
        if (!Backend.isConfigured)
          _Notice(
            text: widget.backendInitializationPending
              ? 'Connecting to Supabase...'
              : widget.backendInitializationFailed
                ? 'Could not connect to Supabase: ${widget.backendInitializationError ?? 'Check your internet connection and restart the app.'}'
                : 'Connect Supabase in lib/config/supabase_config.dart to sign in.'),
        if ((widget.requiredAuth ?? false) || !Backend.isConfigured)
          const SizedBox(height: 18),
        Image.asset('assets/buildhive_icon.png', width: 60, height: 60),
        const Center(
            child: Text('BUILDHIVE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 23))),
        const SizedBox(height: 22),
        if (register) ...[
          TextField(
              controller: fullName,
              decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 10),
          TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone number')),
          const SizedBox(height: 10)
        ],
        TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 10),
        TextField(
            controller: password,
            obscureText: !visible,
            decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                    icon:
                        Icon(visible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => visible = !visible)))),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: busy || widget.backendInitializationPending
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      if (!Backend.isConfigured) {
                        throw Exception(
                            widget.backendInitializationFailed
                                ? 'Supabase connection failed. Check your internet connection and restart the app.'
                                : 'Supabase is not configured. Follow README setup.');
                      }
                      final client = Backend.db;
                      if (register) {
                        final result = await client.auth.signUp(
                            email: email.text.trim(),
                            password: password.text,
                            data: {'full_name': fullName.text.trim()});
                        if (result.session == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Check your email to confirm your account, then sign in.')));
                          }
                          return;
                        }
                        if (result.user != null) {
                          await Backend.createProfile(
                            name: fullName.text.trim(),
                            phone: phone.text.trim(),
                          );
                        }
                      } else {
                        await client.auth.signInWithPassword(
                            email: email.text.trim(), password: password.text);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(register
                                ? 'Account created.'
                                : 'Signed in successfully.')));
                        final onAuthenticated = widget.onAuthenticated;
                        if (onAuthenticated != null) {
                          onAuthenticated();
                        } else {
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Authentication failed: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(widget.backendInitializationPending
              ? 'Connecting...'
              : busy
                ? 'Please wait...'
                : register
                  ? 'Register'
                  : 'Login')),
        TextButton(
            onPressed: () => setState(() => register = !register),
            child: Text(register
                ? 'Already have an account? Login'
                : "Don't have an account? Sign Up")),
        TextButton(
            onPressed: () async {
              if (email.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter your email first.')));
                return;
              }
              if (!Backend.isConfigured) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Supabase is not configured.')));
                return;
              }
              try {
                await Backend.db.auth.resetPasswordForEmail(email.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Password reset email requested.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Forgot password?')),
      ]));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hiveLine.withValues(alpha: .8))),
      child: Row(children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: hiveYellow.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.info_outline_rounded,
                color: hiveBlack, size: 21)),
        const SizedBox(width: 13),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: hiveMuted, fontSize: 14, height: 1.4))),
      ]));
}
