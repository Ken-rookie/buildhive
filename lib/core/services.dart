import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class Backend {
  static bool _isConfigured = false;
  static bool get isConfigured => _isConfigured;

  static Future<bool> initializeIfConfigured({
    required String url,
    required String key,
  }) async {
    if (url.isEmpty || key.isEmpty) return false;

    await Supabase.initialize(url: url, publishableKey: key);
    _isConfigured = true;
    return true;
  }

  static SupabaseClient get db => Supabase.instance.client;

  static Future<String> placeOrder({
    required String checkoutRequestId,
    required String paymentMethod,
    required String deliveryName,
    required String deliveryPhone,
    required String municipalityCode,
    required String municipality,
    required String barangayCode,
    required String barangay,
    required String landmark,
    required String deliveryNotes,
    required List<Map<String, dynamic>> items,
  }) async {
    final result = await db.rpc('place_order_with_stock', params: {
      'p_payment_method': paymentMethod,
      'p_delivery_name': deliveryName,
      'p_delivery_phone': deliveryPhone,
      'p_municipality_code': municipalityCode,
      'p_municipality': municipality,
      'p_barangay_code': barangayCode,
      'p_barangay': barangay,
      'p_landmark': landmark,
      'p_delivery_notes': deliveryNotes,
      'p_items': items,
      'p_checkout_request_id': checkoutRequestId,
    });
    if (result == null) {
      throw StateError('Checkout did not return an order ID.');
    }
    return result.toString();
  }

  static Future<Map<String, String>> _categoryNames() async {
    final rows = await db.from('categories').select('id, name');
    return {
      for (final row in rows) row['id'].toString(): row['name'].toString(),
    };
  }

  static Product _productFromRealtimeRow(
    Map<String, dynamic> row,
    Map<String, String> categoryNames,
  ) {
    return Product.fromMap({
      ...row,
      'category_name': categoryNames[row['category_id']?.toString()] ??
          row['category'] ??
          'Others',
    });
  }

  static Stream<List<Product>> productsStream() async* {
    final categoryNames = await _categoryNames();
    final changes = db
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('name');

    await for (final rows in changes) {
      yield rows
          .map((row) => _productFromRealtimeRow(row, categoryNames))
          .toList();
    }
  }

  static Stream<Product?> productStream(String id) async* {
    final categoryNames = await _categoryNames();
    final changes = db.from('products').stream(primaryKey: ['id']).eq('id', id);

    await for (final rows in changes) {
      Map<String, dynamic>? activeRow;
      for (final row in rows) {
        if (row['is_active'] == true) {
          activeRow = row;
          break;
        }
      }
      yield activeRow == null
          ? null
          : _productFromRealtimeRow(activeRow, categoryNames);
    }
  }

  static Stream<List<Map<String, dynamic>>> customerOrdersStream(
          String customerId) =>
      db
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

  static Future<List<Product>> products(
      {String? category, String query = ''}) async {
    var request = db.from('products').select('*, categories(name)');
    if (category != null && category != 'All') {
      final cat = await db
          .from('categories')
          .select('id')
          .eq('name', category)
          .maybeSingle();
      if (cat != null) {
        request = db
            .from('products')
            .select('*, categories(name)')
            .eq('category_id', cat['id']);
      }
    }
    final rows = await request.eq('is_active', true).order('name');
    return rows
        .map((m) => Product.fromMap(
            {...m, 'category_name': (m['categories'] as Map?)?['name']}))
        .where((p) =>
            query.isEmpty || p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  static Future<void> createProfile(
      {required String name, required String phone}) async {
    final user = db.auth.currentUser;
    if (user == null) return;
    await db
        .from('profiles')
        .upsert({'id': user.id, 'full_name': name, 'phone': phone});
  }
}
