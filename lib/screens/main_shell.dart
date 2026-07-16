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
      backgroundColor: AppColors.paper,
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
            backgroundColor: AppColors.green,
            elevation: 6,
            icon: const Icon(Symbols.shopping_cart,
                size: 20, fill: 1, weight: 600),
            label: Text(
              'Cart · $count',
              style: instrument(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          );
        },
      ),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ── Custom floating dark pill nav bar ─────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: AppColors.paper,
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 14),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.55),
              blurRadius: 34,
              spreadRadius: -10,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            _NavItem(
              icon: Symbols.home,
              label: 'Home',
              index: 0,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Symbols.inventory_2,
              label: 'Inventory',
              index: 1,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Symbols.account_balance_wallet,
              label: 'Khata',
              index: 2,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Symbols.more_horiz,
              label: 'More',
              index: 3,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: selected
              ? Container(
                  key: ValueKey('sel_$index'),
                  height: 46,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          fill: 1,
                          size: 22,
                          color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: instrument(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  key: ValueKey('unsel_$index'),
                  height: 46,
                  child: Center(
                    child: Icon(icon,
                        size: 23, color: AppColors.inkMuted),
                  ),
                ),
        ),
      ),
    );
  }
}
