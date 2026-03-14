import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final couple = context.watch<CoupleProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          CircleAvatar(
            radius: 36,
            child: Text(((user?.displayName.isNotEmpty ?? false) ? user!.displayName[0] : '?').toUpperCase()),
          ),
          const SizedBox(height: 12),
          Text(user?.displayName ?? 'Без имени', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          Text(user?.email ?? '-', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          const Divider(),
          Text('Пара', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (couple.currentCouple != null) ...<Widget>[
            Text('Invite code: ${couple.currentCouple!.inviteCode}'),
            const Text('Статус: Подключён'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Покинуть пару?'),
                    actions: <Widget>[
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Покинуть')),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await context.read<CoupleProvider>().leaveCouple();
                }
              },
              child: const Text('Покинуть пару'),
            ),
          ] else
            ElevatedButton(
              onPressed: () => context.push('/connect-couple'),
              child: const Text('Подключиться к паре'),
            ),
          const Divider(),
          ElevatedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Выйти из аккаунта?'),
                  actions: <Widget>[
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Выйти')),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) context.go('/login');
              }
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
