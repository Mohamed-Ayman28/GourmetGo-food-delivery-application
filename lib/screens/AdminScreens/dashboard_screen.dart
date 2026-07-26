import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../consts/appColors.dart';
import '../login_screen.dart';
import 'tabs/overview_tab.dart';
import 'tabs/staff_tab.dart';
import 'tabs/drivers_tab.dart';
import 'tabs/restaurant_tab.dart';
import 'tabs/menu_tab.dart';
import 'tabs/orders_tab.dart';
import 'settings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    OverviewTab(),
    StaffTab(),
    DriversTab(),
    RestaurantTab(),
    MenuTab(),
    OrdersTab(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Dashboard Overview',
    'Staff Management',
    'Driver Management',
    'Restaurant Management',
    'Menu Management',
    'All Orders',
    'Admin Settings',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (MediaQuery.of(context).size.width <= 800 && Scaffold.of(context).hasDrawer) {
      if(Scaffold.of(context).isDrawerOpen) {
          Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final drawerContent = ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: AppColors.primary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
              SizedBox(height: 10),
              Text('GourmetGo Admin', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        _buildDrawerItem(0, Icons.dashboard, 'Overview'),
        _buildDrawerItem(1, Icons.people, 'Staff'),
        _buildDrawerItem(2, Icons.delivery_dining, 'Drivers'),
        _buildDrawerItem(3, Icons.storefront, 'Restaurant'),
        _buildDrawerItem(4, Icons.restaurant_menu, 'Menu'),
        _buildDrawerItem(5, Icons.receipt_long, 'Orders'),
        _buildDrawerItem(6, Icons.settings, 'Settings'),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: AppColors.error),
          title: const Text('Logout', style: TextStyle(color: AppColors.error)),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 1,
      ),
      drawer: isDesktop ? null : Drawer(child: drawerContent),
      body: isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 250,
                  child: Drawer(
                    elevation: 0,
                    child: drawerContent,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(_titles[_selectedIndex]),
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 1,
                    ),
                    body: _pages[_selectedIndex],
                  ),
                ),
              ],
            )
          : _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primary.withAlpha(25),
      leading: Icon(icon, color: isSelected ? AppColors.primary : AppColors.neutral),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        setState(() {
            _selectedIndex = index;
        });
        if (!isDesktop(context)) {
            Navigator.pop(context); // Close drawer
        }
      },
    );
  }
  
  bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width > 800;
}
