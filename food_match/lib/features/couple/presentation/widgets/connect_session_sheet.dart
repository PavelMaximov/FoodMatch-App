import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../logic/couple_provider.dart';

class ConnectSessionSheet extends StatefulWidget {
  const ConnectSessionSheet({super.key});

  @override
  State<ConnectSessionSheet> createState() => _ConnectSessionSheetState();
}

class _ConnectSessionSheetState extends State<ConnectSessionSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _sessionExpanded = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Consumer<CoupleProvider>(
          builder: (BuildContext context, CoupleProvider coupleProvider, _) {
            final bool hasCouple = coupleProvider.hasCouple;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.link, size: 28, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Joining a session',
                      style: GoogleFonts.pacifico(
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade100,
                        ),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!hasCouple && !_sessionExpanded) ...<Widget>[
                  Text(
                    'Create your own session',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: '+ Create session',
                    isLoading: coupleProvider.isLoading,
                    onPressed: () async {
                      if (coupleProvider.isLoading || coupleProvider.hasCouple) {
                        return;
                      }

                      await coupleProvider.createCouple();
                      if (coupleProvider.currentCouple != null && mounted) {
                        setState(() => _sessionExpanded = true);
                      }
                    },
                  ),
                ],
                if (hasCouple || _sessionExpanded) ...<Widget>[
                  _buildSessionInfoBlock(context, coupleProvider),
                ],
                const SizedBox(height: 32),
                Text(
                  'Join an existing session',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Invite code',
                    hintStyle: GoogleFonts.nunito(color: AppColors.textHint),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Connect to session',
                  isLoading: coupleProvider.isLoading,
                  onPressed: () async {
                    final String code = _codeController.text.trim();
                    if (code.isEmpty) {
                      return;
                    }

                    await coupleProvider.joinCouple(code);
                    if (coupleProvider.currentCouple != null && mounted) {
                      Navigator.pop(context);
                      if (mounted) {
                        SnackBarUtils.showSuccess(context, 'Connected to session!');
                      }
                    } else if (coupleProvider.error != null && mounted) {
                      SnackBarUtils.showError(context, coupleProvider.error!);
                    }
                  },
                ),
                if (coupleProvider.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    coupleProvider.error!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSessionInfoBlock(
    BuildContext context,
    CoupleProvider coupleProvider,
  ) {
    final String inviteCode = coupleProvider.currentCouple?.inviteCode ?? '------';
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? currentUserId = authProvider.currentUser?.id;

    String partnerName = 'Waiting for partner...';
    final List<String> members = coupleProvider.currentCouple?.members ?? <String>[];
    if (members.length >= 2 && currentUserId != null) {
      String? partnerId;
      for (final String memberId in members) {
        if (memberId != currentUserId) {
          partnerId = memberId;
          break;
        }
      }
      if (partnerId != null && partnerId.isNotEmpty) {
        partnerName = 'Partner: $partnerId';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Invite code:',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Text(
              inviteCode,
              style: GoogleFonts.nunito(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: inviteCode));
                SnackBarUtils.showSuccess(context, 'Code copied!');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          partnerName,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await coupleProvider.resetCouple();
                  if (mounted) {
                    SnackBarUtils.showSuccess(context, 'Session reset');
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Reset',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final bool confirm = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext ctx) => AlertDialog(
                          title: const Text('Leave session'),
                          content: const Text('Are you sure you want to leave?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                'Leave',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirm && mounted) {
                    await coupleProvider.leaveCouple();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Leave',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
