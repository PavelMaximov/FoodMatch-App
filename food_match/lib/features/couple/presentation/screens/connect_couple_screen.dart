import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/snackbar_utils.dart';
import '../../logic/couple_provider.dart';

class ConnectCoupleScreen extends StatefulWidget {
  const ConnectCoupleScreen({super.key});

  @override
  State<ConnectCoupleScreen> createState() => _ConnectCoupleScreenState();
}

class _ConnectCoupleScreenState extends State<ConnectCoupleScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createCouple() async {
    final provider = context.read<CoupleProvider>();
    await provider.createCouple();
    if (!mounted) return;
    if (provider.error != null) {
      SnackBarUtils.showError(context, provider.error!);
    }
  }

  Future<void> _joinCouple() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final provider = context.read<CoupleProvider>();
    await provider.joinCouple(code);
    if (!mounted) return;

    if (provider.error != null) {
      SnackBarUtils.showError(context, provider.error!);
      return;
    }

    SnackBarUtils.showSuccess(context, 'Пара успешно подключена');
    context.go('/swipes');
  }

  @override
  Widget build(BuildContext context) {
    final couple = context.watch<CoupleProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Подключение к паре')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Создать пару', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: couple.isLoading ? null : _createCouple,
                        child: const Text('Создать пару'),
                      ),
                      if (couple.inviteCode != null) ...<Widget>[
                        const SizedBox(height: 12),
                        SelectableText(
                          couple.inviteCode!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: couple.inviteCode!));
                            if (!context.mounted) return;
                            SnackBarUtils.showSuccess(context, 'Код скопирован');
                          },
                          child: const Text('Скопировать код'),
                        ),
                        const Text('Отправьте этот код партнёру', textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Присоединиться', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Invite code',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: couple.isLoading ? null : _joinCouple,
                        child: const Text('Присоединиться'),
                      ),
                    ],
                  ),
                ),
              ),
              if (couple.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
