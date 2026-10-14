import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openScan() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onSeeAll: () => setState(() => _index = 1)),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScan,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Scan Struk'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x2212A37A),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
