import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../features/couple/logic/couple_provider.dart';
import '../../../features/couple/presentation/screens/connect_couple_screen.dart';
import '../../../features/matches/logic/match_provider.dart';
import '../../../features/swipes/logic/swipe_provider.dart';
import '../../../shared/widgets/network_status_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AuthProvider auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) return;

      final CoupleProvider couple = context.read<CoupleProvider>();
      await couple.loadCouple();

      if (!couple.hasCouple && mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => const ConnectCoupleScreen(),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SwipeProvider>().syncPendingSwipes();
    }
  }

  void _onTap(int index) {
    if (index == 1) {
      context.read<MatchProvider>().loadMatches();
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int matchCount = context.watch<MatchProvider>().matchCount;

    return Scaffold(
      body: Column(
        children: <Widget>[
          const NetworkStatusBar(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: <NavigationDestination>[
          _destination(icon: Icons.restaurant, label: AppStrings.swipes),
          NavigationDestination(
            icon: _unselectedMatchIcon(matchCount),
            selectedIcon: _selectedIcon(
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Icon(Icons.favorite, color: Colors.white),
                  if (matchCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: _badge(matchCount),
                    ),
                ],
              ),
            ),
            label: AppStrings.matches,
          ),
          _destination(icon: Icons.add_circle, label: AppStrings.addDishes),
          _destination(icon: Icons.person, label: AppStrings.profile),
        ],
      ),
    );
  }

  NavigationDestination _destination({required IconData icon, required String label}) {
    return NavigationDestination(
      icon: Icon(icon, color: AppColors.navInactive),
      selectedIcon: _selectedIcon(Icon(icon, color: Colors.white)),
      label: label,
    );
  }

  Widget _selectedIcon(Widget child) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _unselectedMatchIcon(int matchCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        const Icon(Icons.favorite, color: AppColors.navInactive),
        if (matchCount > 0)
          Positioned(
            right: -8,
            top: -8,
            child: _badge(matchCount),
          ),
      ],
    );
  }

  Widget _badge(int matchCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 18),
      child: Text(
        '$matchCount',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
