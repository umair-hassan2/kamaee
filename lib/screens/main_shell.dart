import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'inventory_screen.dart';
import 'khata_screen.dart';
import 'more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    HomeScreen(),
    InventoryScreen(),
    KhataScreen(),
    MoreScreen(),
  ];

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: CartService().cartCount,
        builder: (_, count, __) {
          if (count == 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _openCart,
            backgroundColor: AppColors.primary,
            elevation: 4,
            icon: const Icon(Symbols.shopping_cart, size: 20,
                fill: 1, weight: 600),
            label: Text(
              'Cart · $count',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          );
        },
      ),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Symbols.home, size: 22),
              selectedIcon: Icon(Symbols.home,
                  size: 22, fill: 1, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Symbols.inventory_2, size: 22),
              selectedIcon: Icon(Symbols.inventory_2,
                  size: 22, fill: 1, color: AppColors.primary),
              label: 'Inventory',
            ),
            NavigationDestination(
              icon: Icon(Symbols.account_balance_wallet, size: 22),
              selectedIcon: Icon(Symbols.account_balance_wallet,
                  size: 22, fill: 1, color: AppColors.primary),
              label: 'Khata',
            ),
            NavigationDestination(
              icon: Icon(Symbols.more_horiz, size: 22),
              selectedIcon: Icon(Symbols.more_horiz,
                  size: 22, fill: 1, color: AppColors.primary),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
