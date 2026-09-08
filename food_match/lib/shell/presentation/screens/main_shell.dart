import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/animations/app_motion.dart';
import '../../../core/theme/notification_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/food_match_notifications.dart';
import '../../../data/models/couple_invitation.dart';
import '../../../features/auth/logic/auth_provider.dart';
import '../../../features/couple/logic/couple_provider.dart';
import '../../../features/couple/presentation/widgets/continuation_invitation_sheet.dart';
import '../../../features/matches/logic/match_provider.dart';
import '../../../features/swipes/logic/swipe_provider.dart';
import '../../../shared/widgets/network_status_bar.dart';
import '../../logic/nav_badge_animation_controller.dart';
import '../widgets/matches_nav_badge.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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
  String? _shownInvitationId;
  late final AnimationController _soloPlusOneController;
  NavBadgeAnimationController? _navBadgeAnimationController;
  int _lastSoloPlusOneEvent = 0;
  Timer? _matchBadgeRefreshTimer;

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
    _soloPlusOneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _soloPlusOneController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && kDebugMode) {
        debugPrint('[NavBadgeAnim] complete');
      }
    });
    _navBadgeAnimationController = context.read<NavBadgeAnimationController>()
      ..addListener(_handleNavBadgeAnimationEvent);
    _lastSoloPlusOneEvent =
        _navBadgeAnimationController!.soloMatchesPlusOneEvent;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bootstrapMatchesBadge();
        _startMatchBadgeRefresh();
        context.read<CoupleProvider>().startInvitationPolling(
          reason: 'main_shell',
        );
      }
    });
  }

  @override
  void dispose() {
    _navBadgeAnimationController?.removeListener(_handleNavBadgeAnimationEvent);
    _soloPlusOneController.dispose();
    _matchBadgeRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleNavBadgeAnimationEvent() {
    final int event =
        _navBadgeAnimationController?.soloMatchesPlusOneEvent ?? 0;
    if (event == _lastSoloPlusOneEvent || !mounted) {
      return;
    }
    _lastSoloPlusOneEvent = event;
    if (kDebugMode) {
      debugPrint('[BottomNavBadge] animate +1 delta=1 bumpToken=$event');
    }
    _soloPlusOneController
      ..stop()
      ..reset()
      ..forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CoupleProvider>().handleAppResumed();
      context.read<SwipeProvider>().syncPendingSwipes();
      unawaited(_refreshMatchBadge(reason: 'app_resume'));
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<CoupleProvider>().handleAppPaused();
    }
  }

  void _startMatchBadgeRefresh() {
    _matchBadgeRefreshTimer?.cancel();
    _matchBadgeRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_refreshMatchBadge(reason: 'shell_poll')),
    );
  }

  Future<void> _refreshMatchBadge({required String reason}) async {
    if (!mounted) return;
    final AuthProvider authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    if (authProvider.currentUser == null) {
      await authProvider.loadUser();
      if (!mounted) return;
    }
    final String? userId = authProvider.currentUser?.id;
    if (userId == null) {
      debugPrint('[MatchProvider] user unresolved reason=$reason');
      return;
    }
    context.read<MatchProvider>().setActiveUser(userId);
    final NavBadgeAnimationController badge =
        context.read<NavBadgeAnimationController>();
    if (badge.sessionId == null) return;
    if (kDebugMode) {
      debugPrint('[MatchBadge] refresh requested reason=$reason');
    }
    await context.read<MatchProvider>().loadMatches(force: true);
  }

  void _onTabTap(int index) {
    if (index < 0 ||
        index >= _navItems.length ||
        index == widget.navigationShell.currentIndex) {
      return;
    }
    if (index == 1) {
      context.read<MatchProvider>().loadMatches();
    }

    widget.navigationShell.goBranch(index);
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

  Future<void> _showContinuationInvitation(CoupleInvitation invitation) async {
    if (!mounted) return;
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (BuildContext sheetContext) => ContinuationInvitationSheet(
        invitation: invitation,
        onJoin: () async {
          Navigator.pop(sheetContext);
          await coupleProvider.acceptInvitation(invitation);
          if (!mounted) return;
          widget.navigationShell.goBranch(2);
          FoodMatchNotifications.show(
            context,
            type: FoodMatchNotificationType.success,
            title: 'Session joined.',
          );
        },
        onDecline: () async {
          Navigator.pop(sheetContext);
          await coupleProvider.declineInvitation(invitation);
          if (!mounted) return;
          FoodMatchNotifications.show(
            context,
            type: FoodMatchNotificationType.info,
            title: 'Invitation declined.',
          );
        },
      ),
    );
    if (mounted) {
      coupleProvider.hideInvitationLocally(invitation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int matchCount = context.select<NavBadgeAnimationController, int>(
      (NavBadgeAnimationController controller) => controller.badgeCount,
    );
    final MatchProvider matchProvider = context.read<MatchProvider>();
    final int currentIndex = widget.navigationShell.currentIndex;
    final FoodMatchThemeColors colors = context.fmColors;
    final CoupleInvitation? invitation = context
        .select<CoupleProvider, CoupleInvitation?>(
          (CoupleProvider provider) => provider.nextIncomingInvitation,
        );
    if (invitation != null && invitation.id != _shownInvitationId) {
      _shownInvitationId = invitation.id;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showContinuationInvitation(invitation),
      );
    }
    final bool shouldOpenPreviousChoice = context.select<CoupleProvider, bool>(
      (CoupleProvider provider) => provider.shouldOpenPreviousChoiceAfterInvite,
    );
    if (shouldOpenPreviousChoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.navigationShell.goBranch(2);
      });
    }

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
                          SizedBox(
                            width: 40,
                            height: 32,
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                AnimatedScale(
                                  scale: isActive ? 1 : 0.76,
                                  duration: AppMotion.durationFor(
                                    context,
                                    AppMotion.indicatorScale,
                                  ),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: isActive ? 1 : 0,
                                    duration: AppMotion.durationFor(
                                      context,
                                      AppMotion.fast,
                                    ),
                                    curve: AppMotion.curve,
                                    child: Container(
                                      width: 40,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: colors.bottomNavActiveIndicator,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                _BottomNavIcon(
                                  item: item,
                                  isActive: isActive,
                                  assetExists: _hasIconAsset(
                                    item.iconAssetFor(isActive: isActive),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index == 1)
                            Positioned.fill(
                              child: MatchesNavBadge(
                                count: matchCount,
                                mode: _navBadgeAnimationController?.mode ??
                                    matchProvider.mode,
                                sessionId:
                                    _navBadgeAnimationController?.sessionId,
                                bumpToken:
                                    _navBadgeAnimationController?.bumpToken ?? 0,
                                animation: _soloPlusOneController,
                                animationEventKey:
                                    _navBadgeAnimationController
                                        ?.lastSoloMatchesPlusOneEventKey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: AppMotion.durationFor(
                          context,
                          AppMotion.fast,
                        ),
                        curve: AppMotion.curve,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isActive
                              ? colors.bottomNavActive
                              : colors.bottomNavInactive,
                        ),
                        child: Text(item.label),
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
    final Color iconColor = isActive
        ? colors.bottomNavActive
        : colors.bottomNavInactive;
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
