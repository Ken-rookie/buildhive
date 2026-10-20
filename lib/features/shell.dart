import 'package:flutter/material.dart';
import 'screens.dart';

class BuildHiveShell extends StatefulWidget {
  const BuildHiveShell({
    super.key,
    required this.backendConfigured,
    this.initialTab = 0,
    this.onSignedOut,
  });
  final bool backendConfigured;
  final int initialTab;
  final VoidCallback? onSignedOut;
  @override
  State<BuildHiveShell> createState() => _BuildHiveShellState();
}

class _BuildHiveShellState extends State<BuildHiveShell> {
  late int tab;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant BuildHiveShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        backendConfigured: widget.backendConfigured,
        onSeeCategories: () => setState(() => tab = 1),
      ),
      const CategoryScreen(),
      const CartScreen(),
      const OrdersScreen(),
      ProfileScreen(onSignedOut: widget.onSignedOut),
    ];
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth > 480 ? 480.0 : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: pages[tab],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barWidth =
                constraints.maxWidth > 480 ? 480.0 : constraints.maxWidth;
            return SizedBox(
              height: 68,
              child: Center(
                child: SizedBox(
                  width: barWidth,
                  child: NavigationBar(
                    selectedIndex: tab,
                    onDestinationSelected: (v) => setState(() => tab = v),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: 'Home'),
                      NavigationDestination(
                          icon: Icon(Icons.grid_view_outlined),
                          label: 'Categories'),
                      NavigationDestination(
                          icon: Icon(Icons.shopping_cart_outlined),
                          label: 'Cart'),
                      NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          label: 'Orders'),
                      NavigationDestination(
                          icon: Icon(Icons.person_outline), label: 'Profile'),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
