import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/logic/auth_provider.dart';
import '../../../features/couple/logic/couple_provider.dart';
import '../../../features/matches/logic/match_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final couple = context.read<CoupleProvider>();
      if (auth.isAuthenticated && couple.currentCouple == null) {
        context.push('/connect-couple');
      }
    });
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
    final matchCount = context.watch<MatchProvider>().matchCount;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: <NavigationDestination>[
          const NavigationDestination(icon: Icon(Icons.swipe), label: 'Свайпы'),
          NavigationDestination(
            icon: Badge(
              label: Text(matchCount.toString()),
              isLabelVisible: matchCount > 0,
              child: const Icon(Icons.favorite),
            ),
            label: 'Матчи',
          ),
          const NavigationDestination(icon: Icon(Icons.add_circle), label: 'Добавить'),
          const NavigationDestination(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}
