import 'package:flutter/material.dart';

import 'tabs/home_screen.dart';
import 'tabs/report_screen.dart';
import 'tabs/my_reports_screen.dart';
import 'tabs/map_screen.dart';
import 'tabs/alerts_screen.dart';
import 'tabs/family_notifications_screen.dart';
import '../utils/role_helper.dart';
import '../utils/app_colors.dart';

class MainShell extends StatefulWidget {
  static const String routeName = '/';
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;
  
  bool get _showAlertsTab {
    return RoleHelper.isHeadBarangayOfficial() || RoleHelper.isBarangayOfficial();
  }

  Widget _pageForIndex(int index) {
    if (_showAlertsTab) {
      switch (index) {
        case 0:
          return const HomeScreen();
        case 1:
          return const ReportScreen();
        case 2:
          return const MyReportsScreen();
        case 3:
          return const MapScreen();
        case 4:
          return const AlertsScreen();
        case 5:
          return const FamilyNotificationsScreen();
        default:
          return const HomeScreen();
      }
    } else {
      switch (index) {
        case 0:
          return const HomeScreen();
        case 1:
          return const ReportScreen();
        case 2:
          return const MyReportsScreen();
        case 3:
          return const MapScreen();
        case 4:
          return const FamilyNotificationsScreen();
        default:
          return const HomeScreen();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _showAlertsTab
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_alert_outlined), activeIcon: Icon(Icons.add_alert), label: 'Create'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'My Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.family_restroom_outlined), activeIcon: Icon(Icons.family_restroom), label: 'Family'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_alert_outlined), activeIcon: Icon(Icons.add_alert), label: 'Create'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'My Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.family_restroom_outlined), activeIcon: Icon(Icons.family_restroom), label: 'Family'),
          ];
    
    return Scaffold(
      body: _pageForIndex(currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        items: items,
        type: items.length > 5 ? BottomNavigationBarType.shifting : BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}


