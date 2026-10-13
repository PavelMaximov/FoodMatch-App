import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/notification_theme.dart';
import '../../../core/utils/food_match_notifications.dart';
import '../domain/premium_entry_point.dart';
import 'premium_plan_presentation.dart';
import 'widgets/compact_premium_widgets.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({
    super.key,
    this.entryPoint = PremiumEntryPoint.overview,
  });
  final PremiumEntryPoint entryPoint;
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  PremiumPlanSelection _selection = PremiumPlanSelection.yearly;

  void _comingSoon() {
    // TODO(IAP): Delegate purchase and restore to the real purchase coordinator.
    FoodMatchNotifications.show(
      context,
      type: FoodMatchNotificationType.info,
      title: 'Subscriptions coming soon',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.fmColors.background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final compact = constraints.maxHeight < 820;
          final fallback =
              constraints.maxHeight < 640 ||
              (scale > 1.3 && constraints.maxHeight < 800) ||
              scale > 1.6;
          final content = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: fallback ? MainAxisSize.min : MainAxisSize.max,
              spacing: compact ? 10 : 16,
              children: [
                PremiumHero(crownHeight: compact ? 72 : 90),
                const PremiumBenefitsCard(),
                PremiumPlansSection(
                  selection: _selection,
                  onSelected: (value) => setState(() => _selection = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('premium-cta'),
                    onPressed: _comingSoon,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.fmColors.buttonPrimaryBackground,
                      foregroundColor: context.fmColors.buttonPrimaryText,
                      minimumSize: const Size(44, 48),
                      textStyle: premiumText(
                        context,
                        17,
                        weight: FontWeight.w800,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _selection == PremiumPlanSelection.yearly
                          ? PremiumPlanPresentation.yearly.cta
                          : PremiumPlanPresentation.monthly.cta,
                    ),
                  ),
                ),
                PremiumFooter(onRestore: _comingSoon),
              ],
            ),
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: fallback
                  ? SingleChildScrollView(
                      key: const ValueKey('premium-accessibility-scroll'),
                      child: content,
                    )
                  : SizedBox(height: constraints.maxHeight, child: content),
            ),
          );
        },
      ),
    ),
  );
}
