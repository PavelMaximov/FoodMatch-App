import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_extensions.dart';
import '../../../features/couple/logic/couple_provider.dart';
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
  static const List<BottomNavItemData> _navItems = <BottomNavItemData>[
    BottomNavItemData(
      label: 'Recipes',
      inactiveIconAsset: 'assets/icons/nav/recipes_outline.svg',
      activeIconAsset: 'assets/icons/nav/recipes_fill.svg',
      fallbackIcon: Icons.restaurant_menu,
    ),
    BottomNavItemData(
      label: 'Matches',
      inactiveIconAsset: 'assets/icons/nav/matches_outline.svg',
      activeIconAsset: 'assets/icons/nav/matches_fill.svg',
      fallbackIcon: Icons.favorite,
    ),
    BottomNavItemData(
      label: 'Swipes',
      inactiveIconAsset: 'assets/icons/nav/swipes_outline.svg',
      activeIconAsset: 'assets/icons/nav/swipes_fill.svg',
      fallbackIcon: Icons.swipe,
    ),
    BottomNavItemData(
      label: 'Add dishes',
      inactiveIconAsset: 'assets/icons/nav/add_dish_outline.svg',
      activeIconAsset: 'assets/icons/nav/add_dish_fill.svg',
      fallbackIcon: Icons.add_circle,
    ),
    BottomNavItemData(
      label: 'Profile',
      inactiveIconAsset: 'assets/icons/nav/profile_outline.svg',
      activeIconAsset: 'assets/icons/nav/profile_fill.svg',
      fallbackIcon: Icons.person,
    ),
  ];

  final Map<String, Future<bool>> _iconAssetAvailability =
      <String, Future<bool>>{};
  bool _isBootstrappingMatchesBadge = false;

  Future<bool> _hasIconAsset(String assetPath) {
    return _iconAssetAvailability.putIfAbsent(assetPath, () async {
      try {
        await rootBundle.load(assetPath);
        return true;
      } catch (_) {
        if (kDebugMode) {
          debugPrint('[MainShell] Missing bottom nav SVG asset: $assetPath');
        }
        return false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bootstrapMatchesBadge();
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
      context.read<CoupleProvider>().handleAppResumed();
      context.read<SwipeProvider>().syncPendingSwipes();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<CoupleProvider>().handleAppPaused();
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

  Future<void> _bootstrapMatchesBadge() async {
    if (_isBootstrappingMatchesBadge) {
      return;
    }
    _isBootstrappingMatchesBadge = true;
    try {
      final CoupleProvider coupleProvider = context.read<CoupleProvider>();
      await coupleProvider.loadCouple(force: true);
      if (!mounted) {
        return;
      }
      final MatchProvider matchProvider = context.read<MatchProvider>();
      if (coupleProvider.hasCouple) {
        matchProvider.setActiveCouple(
          coupleProvider.currentCouple?.id,
          sessionStateVersion: coupleProvider.sessionStateVersion,
        );
        return;
      }
      final SwipeProvider swipeProvider = context.read<SwipeProvider>();
      final bool hasActiveSolo = await swipeProvider.loadActiveSoloSession();
      if (!mounted) {
        return;
      }
      if (hasActiveSolo) {
        matchProvider.setSoloSession(swipeProvider.activeSoloSessionId);
        await matchProvider.loadMatches(
          force: true,
          mode: 'solo',
          soloSessionId: swipeProvider.activeSoloSessionId,
        );
      } else {
        matchProvider.clearMatches();
      }
    } finally {
      _isBootstrappingMatchesBadge = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int matchCount = context.select<MatchProvider, int>((MatchProvider p) => p.matchCount);
    final int currentIndex = widget.navigationShell.currentIndex;
    final FoodMatchThemeColors colors = context.fmColors;

    return Scaffold(
      body: Column(
        children: <Widget>[
          const NetworkStatusBar(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: colors.bottomNavBackground,
        elevation: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List<Widget>.generate(_navItems.length, (int index) {
              final bool isActive = currentIndex == index;
              final BottomNavItemData item = _navItems[index];

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
                                  ? colors.bottomNavActiveIndicator
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _BottomNavIcon(
                              item: item,
                              isActive: isActive,
                              assetExists: _hasIconAsset(
                                item.iconAssetFor(isActive: isActive),
                              ),
                            ),
                          ),
                          if (index == 1 && matchCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: colors.badgeBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.bottomNavBackground,
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
                                    color: colors.badgeText,
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
                          color: isActive ? colors.bottomNavActive : colors.bottomNavInactive,
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

class BottomNavItemData {
  const BottomNavItemData({
    required this.label,
    required this.inactiveIconAsset,
    required this.activeIconAsset,
    required this.fallbackIcon,
  });

  final String label;
  final String inactiveIconAsset;
  final String activeIconAsset;
  final IconData fallbackIcon;

  String iconAssetFor({required bool isActive}) =>
      isActive ? activeIconAsset : inactiveIconAsset;
}

class _BottomNavIcon extends StatelessWidget {
  const _BottomNavIcon({
    required this.item,
    required this.isActive,
    required this.assetExists,
  });

  final BottomNavItemData item;
  final bool isActive;
  final Future<bool> assetExists;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final Color iconColor = isActive ? colors.bottomNavActive : colors.bottomNavInactive;
    final String iconAsset = item.iconAssetFor(isActive: isActive);

    return Center(
      child: FutureBuilder<bool>(
        future: assetExists,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          final bool useSvg = snapshot.data ?? false;
          if (useSvg) {
            return SvgPicture.asset(
              iconAsset,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              placeholderBuilder: (_) =>
                  Icon(item.fallbackIcon, size: 20, color: iconColor),
            );
          }

          return Icon(item.fallbackIcon, size: 20, color: iconColor);
        },
      ),
    );
  }
}
