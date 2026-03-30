import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../logic/couple_provider.dart';
import '../../../../core/constants/app_strings.dart';

class ConnectCoupleScreen extends StatefulWidget {
  final bool isBottomSheet;

  const ConnectCoupleScreen({
    super.key,
    this.isBottomSheet = false,
  });

  @override
  State<ConnectCoupleScreen> createState() => _ConnectCoupleScreenState();
}

class _ConnectCoupleScreenState extends State<ConnectCoupleScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _isPresentedAsBottomSheet(BuildContext context) {
    return widget.isBottomSheet || ModalRoute.of(context) is PopupRoute<dynamic>;
  }

  Future<void> _createCouple() async {
    await context.read<CoupleProvider>().createCouple();
  }

  Future<void> _joinCouple() async {
    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      return;
    }

    final CoupleProvider provider = context.read<CoupleProvider>();
    await provider.joinCouple(code);
    if (!mounted || provider.error != null) {
      return;
    }

    if (_isPresentedAsBottomSheet(context)) {
      Navigator.of(context).pop(true);
      return;
    }

    context.go('/swipes');
  }

  Future<void> _copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(AppStrings.codeCopied)));
  }

  Widget _buildContent(CoupleProvider provider) {
    final String? inviteCode = provider.inviteCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: AppDimensions.paddingL),
          const Icon(
            Icons.link,
            size: AppDimensions.iconSizeL,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(AppStrings.joiningSession, style: AppTextStyles.screenHeader),
          const SizedBox(height: AppDimensions.paddingXL),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(AppStrings.createSession, style: AppTextStyles.bodyMedium),
          ),
          const SizedBox(height: 12),
          AppButton(
            text: AppStrings.createPair,
            icon: Icons.link,
            onPressed: _createCouple,
            isLoading: provider.isLoading,
          ),
          if (inviteCode != null) ...<Widget>[
            const SizedBox(height: AppDimensions.paddingM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: Column(
                children: <Widget>[
                  Text(AppStrings.yourInviteCode, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    inviteCode,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionHeader,
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  TextButton.icon(
                    onPressed: () => _copyInviteCode(inviteCode),
                    icon: const Icon(Icons.copy, color: AppColors.primary),
                    label: const Text(AppStrings.copyCode),
                  ),
                  Text(
                    AppStrings.shareCode,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.paddingXL),
          Row(
            children: <Widget>[
              const Expanded(child: Divider(color: AppColors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                child: Text(AppStrings.or, style: AppTextStyles.bodySmall),
              ),
              const Expanded(child: Divider(color: AppColors.divider)),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingXL),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(AppStrings.joinExisting, style: AppTextStyles.bodyMedium),
          ),
          const SizedBox(height: 12),
          AppTextField(
            hint: AppStrings.inviteCode,
            controller: _codeController,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          AppButton(
            text: AppStrings.connectToSession,
            onPressed: _joinCouple,
            isLoading: provider.isLoading,
          ),
          if (provider.error != null) ...<Widget>[
            const SizedBox(height: AppDimensions.paddingM),
            Text(
              provider.error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CoupleProvider provider = context.watch<CoupleProvider>();
    final Widget content = SafeArea(child: _buildContent(provider));

    if (_isPresentedAsBottomSheet(context)) {
      return Container(
        color: AppColors.background,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: content,
    );
  }
}
