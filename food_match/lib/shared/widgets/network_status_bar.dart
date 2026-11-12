import 'package:food_match/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

class NetworkStatusBar extends StatefulWidget {
  const NetworkStatusBar({super.key})
    : _initialOnline = null,
      _skipConnectivityChecks = false;

  @visibleForTesting
  const NetworkStatusBar.offlineForTest({super.key})
    : _initialOnline = false,
      _skipConnectivityChecks = true;

  final bool? _initialOnline;
  final bool _skipConnectivityChecks;

  @override
  State<NetworkStatusBar> createState() => _NetworkStatusBarState();
}

class _NetworkStatusBarState extends State<NetworkStatusBar> {
  late bool _isOnline = widget._initialOnline ?? true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget._skipConnectivityChecks) {
      _checkConnectivity();
      _timer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkConnectivity(),
      );
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      final bool online =
          result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      if (mounted && online != _isOnline) {
        setState(() => _isOnline = online);
      }
    } catch (_) {
      if (mounted && _isOnline) {
        setState(() => _isOnline = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: AppColors.textSecondary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.wifi_off, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.tr(AppStrings.noInternet),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
