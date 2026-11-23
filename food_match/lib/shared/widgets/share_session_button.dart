import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/links/session_invitation.dart';
import '../../l10n/app_localizations.dart';

class ShareSessionButton extends StatefulWidget {
  const ShareSessionButton({super.key, required this.code});
  final String code;

  @override
  State<ShareSessionButton> createState() => _ShareSessionButtonState();
}

class _ShareSessionButtonState extends State<ShareSessionButton> {
  static const _channel = MethodChannel('foodmatch/session_share');
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final link = sessionInvitationLink(widget.code);
      await _channel.invokeMethod<void>('share', {
        'text': context.tr('Join my FoodMatch session. Code: {code}', {
          'code': widget.code,
        }),
        'url': link.toString(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Unable to share. Copy the invitation code instead.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed:
        _sharing || invitationCode(sessionInvitationLink(widget.code)) == null
        ? null
        : _share,
    icon: const Icon(Icons.ios_share, size: 18),
    label: Text(context.tr('Share invitation')),
  );
}
