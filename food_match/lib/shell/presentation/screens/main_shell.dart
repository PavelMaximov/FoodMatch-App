import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../features/couple/logic/couple_provider.dart';
import '../../../features/couple/presentation/widgets/connect_session_sheet.dart';
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
  static const List<_NavItem> _navItems = <_NavItem>[
    _NavItem(icon: Icons.restaurant_menu, label: 'Recipes'),
    _NavItem(icon: Icons.favorite, label: 'Matches'),
    _NavItem(icon: Icons.swipe, label: 'Swipes'),
    _NavItem(icon: Icons.add_circle, label: 'Add dishes'),
    _NavItem(icon: Icons.person, label: 'Profile'),
  ];

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
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.5),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => const ConnectSessionSheet(),
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

  void _onTabTap(int index) {
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
    final int currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      body: Column(
        children: <Widget>[
          const NetworkStatusBar(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFFFFBF9),
        elevation: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List<Widget>.generate(_navItems.length, (int index) {
              final bool isActive = currentIndex == index;
              final _NavItem item = _navItems[index];

              return GestureDetector(
                onTap: () => _onTabTap(index),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.navActiveIndicator
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: isActive ? AppColors.navActiveIcon : AppColors.navIcon,
                            ),
                          ),
                          if (index == 1 && matchCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: AppColors.navBadgeBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFFBF9),
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  matchCount > 99 ? '99+' : matchCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navBadgeText,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: AppColors.navText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
