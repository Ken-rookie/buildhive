import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildhive/app.dart';
import 'package:buildhive/core/bohol_address_service.dart';
import 'package:buildhive/core/models.dart';
import 'package:buildhive/features/screens.dart';
import 'package:buildhive/features/shell.dart';

void main() {
  testWidgets('tracking displays saved delivery, payment and order details',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = <String, dynamic>{
      'id': '12345678-abcd',
      'status': 'out_for_delivery',
      'created_at': '2026-10-17T10:30:00Z',
      'delivery_name': 'Maya Builder',
      'delivery_phone': '09171234567',
      'delivery_barangay': 'Poblacion',
      'delivery_municipality': 'Tagbilaran City',
      'delivery_landmark': 'Near the plaza',
      'delivery_notes': 'Call on arrival',
      'payment_method': 'cod',
      'payment_status': 'pending',
      'subtotal': 900,
      'delivery_fee': 0,
      'total': 900,
    };

    await tester.pumpWidget(MaterialApp(home: TrackingScreen(order: order)));
    await tester.pumpAndSettle();

    expect(find.text('Order #12345678'), findsOneWidget);
    expect(find.text('Maya Builder'), findsOneWidget);
    expect(find.text('09171234567'), findsOneWidget);
    expect(find.text('Poblacion, Tagbilaran City, Bohol'), findsOneWidget);
    expect(find.text('Near the plaza'), findsOneWidget);
    expect(find.text('Call on arrival'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
    expect(find.text('₱900.00'), findsNWidgets(2));
    expect(find.text('Out for delivery'), findsWidgets);
    expect(
        find.text(
            'Live driver location is unavailable until a driver-tracking provider is connected.'),
        findsOneWidget);
    expect(find.text('₱980.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('checkout municipality options are limited to Bohol', () {
    final municipalities = BoholAddressService.municipalities;

    expect(municipalities, hasLength(48));
    expect(
        municipalities.every((area) => area.code.startsWith('0712')), isTrue);
    expect(
        municipalities.any((area) => area.name == 'Tagbilaran City'), isTrue);
    expect(
      () => BoholAddressService.barangaysFor(
        const BoholArea(code: '072217000', name: 'Outside Bohol'),
      ),
      throwsArgumentError,
    );
  });

  testWidgets('checkout remembers contact, landmark and delivery notes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('checkout-name')), 'Maya');
    await tester.enterText(
        find.byKey(const ValueKey('checkout-phone')), '09171234567');
    await tester.enterText(
        find.byKey(const ValueKey('checkout-landmark')), 'Near the town plaza');
    await tester.enterText(
        find.byKey(const ValueKey('checkout-notes')), 'Call on arrival');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('buildhive_checkout_name'), 'Maya');
    expect(prefs.getString('buildhive_checkout_phone'), '09171234567');
    expect(
        prefs.getString('buildhive_checkout_landmark'), 'Near the town plaza');
    expect(prefs.getString('buildhive_checkout_notes'), 'Call on arrival');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unauthenticated startup requires login before app access',
      (tester) async {
    SharedPreferences.setMockInitialValues({'buildhive_onboarding_seen': true});
    await tester.pumpWidget(const BuildHiveApp(backendConfigured: false));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(BuildHiveShell), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
        find.text('Sign in or create an account to continue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup renders splash before Supabase initialization completes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backendInitialization = Completer<bool>();

    await tester.pumpWidget(BuildHiveApp(
      backendConfigured: false,
      backendInitialization: backendInitialization.future,
    ));
    await tester.pump();

    expect(find.text('Build More. Deliver Faster.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    backendInitialization.complete(false);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });

  testWidgets('auth reports Supabase initialization failure accurately',
      (tester) async {
    SharedPreferences.setMockInitialValues({'buildhive_onboarding_seen': true});
    final backendInitialization = Completer<bool>();

    await tester.pumpWidget(BuildHiveApp(
      backendConfigured: false,
      backendInitialization: backendInitialization.future,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Connecting to Supabase...'), findsOneWidget);

    backendInitialization.completeError(StateError('network unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Could not connect to Supabase: Bad state: network unavailable'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding photos swipe and Get Started opens login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BuildHiveApp(backendConfigured: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Tools for every build'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Materials that build strong'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('buildhive_onboarding_seen'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest app tabs work without Supabase configured',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BuildHiveShell(backendConfigured: false),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Good day, Builder!'), findsOneWidget);
    final navigationBar = tester.getRect(find.byType(NavigationBar));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(navigationBar.bottom, closeTo(screenHeight, 1));
    expect(navigationBar.width, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Login / Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login / Register'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product details show stock and Buy Now quantity',
      (tester) async {
    CartStore.items.clear();
    const product = Product(
      id: 'demo-cement',
      name: 'Demo Cement Bag',
      category: 'Cement',
      price: 450,
      stock: 20,
      unit: 'bag',
    );

    await tester.pumpWidget(const MaterialApp(
      home: ProductDetailScreen(product: product),
    ));
    expect(find.text('Stock: 20 bag'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
    expect(find.text('Buy Now'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsOneWidget);
    final checkout = tester.widget<CheckoutScreen>(find.byType(CheckoutScreen));
    expect(checkout.buyNowQuantity, 2);
    expect(checkout.subtotal, 900);
    expect(CartStore.items, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product details update stock from the realtime stream',
      (tester) async {
    const initialProduct = Product(
      id: 'demo-cement',
      name: 'Demo Cement Bag',
      category: 'Cement',
      price: 450,
      stock: 20,
      unit: 'bag',
    );
    const updatedProduct = Product(
      id: 'demo-cement',
      name: 'Demo Cement Bag',
      category: 'Cement',
      price: 450,
      stock: 7,
      unit: 'bag',
    );
    final stockUpdates = StreamController<Product?>();

    await tester.pumpWidget(MaterialApp(
      home: ProductDetailScreen(
        product: initialProduct,
        stockUpdates: stockUpdates.stream,
      ),
    ));
    expect(find.text('Stock: 20 bag'), findsOneWidget);

    stockUpdates.add(updatedProduct);
    await tester.pump();

    expect(find.text('Stock: 7 bag'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await stockUpdates.close();
  });
}
