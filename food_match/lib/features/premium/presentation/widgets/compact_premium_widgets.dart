import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../premium_plan_presentation.dart';

TextStyle premiumText(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => GoogleFonts.nunito(
  fontSize: size,
  fontWeight: weight,
  height: 1.15,
  color: color ?? context.fmColors.textPrimary,
);

class PremiumHero extends StatelessWidget {
  const PremiumHero({super.key, required this.crownHeight});
  final double crownHeight;
  @override
  Widget build(BuildContext context) => Column(
    spacing: 6,
    children: [
      SizedBox(
        height: crownHeight,
        child: Stack(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: crownHeight * .9,
                    height: crownHeight * .5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.fmColors.accent.withValues(alpha: .32),
                          blurRadius: 28,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Image.asset(
                      'assets/profile/premium_crown_stars.png',
                      height: crownHeight,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                key: const ValueKey('premium-close'),
                tooltip: 'Close Premium',
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: context.fmColors.cardElevated,
                  foregroundColor: context.fmColors.textSecondary,
                  side: BorderSide(color: context.fmColors.border),
                ),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
      Semantics(
        header: true,
        child: Text(
          'Unlock Premium',
          textAlign: TextAlign.center,
          style: premiumText(context, 35, weight: FontWeight.w900),
        ),
      ),
      Text(
        'Get more powerful tools for smarter\nmeal planning.',
        textAlign: TextAlign.center,
        style: premiumText(context, 16, color: context.fmColors.textSecondary),
      ),
    ],
  );
}

class PremiumBenefitsCard extends StatelessWidget {
  const PremiumBenefitsCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: context.fmColors.card,
      border: Border.all(color: context.fmColors.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      spacing: 18,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PremiumBenefit(
                icon: Icons.block,
                iconColor: Color.fromRGBO(252, 252, 252, 1),
                iconBackgroundColor: Color.fromRGBO(248, 87, 34, 1),
                title: 'No ads',
                description: 'Enjoy a clean and focused experience.',
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: PremiumBenefit(
                icon: Icons.history,
                iconColor: Color.fromRGBO(252, 252, 252, 1),
                iconBackgroundColor: Color.fromRGBO(223, 66, 85, 1),
                title: 'Session history',
                description: 'Revisit your previous FoodMatch sessions.',
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PremiumBenefit(
                icon: Icons.shopping_cart_outlined,
                iconColor: Color.fromRGBO(252, 252, 252, 1),
                iconBackgroundColor: Color.fromRGBO(121, 184, 54, 1),
                title: 'Shopping lists',
                description: 'Turn recipes into organized shopping lists.',
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: PremiumBenefit(
                icon: Icons.restaurant_menu,
                iconColor: Color.fromRGBO(252, 252, 252, 1),
                iconBackgroundColor: Color.fromRGBO(254, 169, 53, 1),
                title: 'Unlimited custom dishes',
                description: 'Create and save your own dishes without limits.',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class PremiumBenefit extends StatelessWidget {
  const PremiumBenefit({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
    this.iconBackgroundColor,
  });
  final IconData icon;
  final String title, description;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 6,
    children: [
      Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBackgroundColor ?? context.fmColors.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? context.fmColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: premiumText(context, 16, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
      Text(
        description,
        style: premiumText(context, 13, color: context.fmColors.textSecondary),
      ),
    ],
  );
}

class PremiumPlansSection extends StatelessWidget {
  const PremiumPlansSection({
    super.key,
    required this.selection,
    required this.onSelected,
  });
  final PremiumPlanSelection selection;
  final ValueChanged<PremiumPlanSelection> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final plan in const [
            PremiumPlanPresentation.monthly,
            PremiumPlanPresentation.yearly,
          ]) ...[
            if (plan.selection == PremiumPlanSelection.yearly)
              const SizedBox(width: 10),
            Expanded(
              child: PremiumPlanCard(
                plan: plan,
                selected: selection == plan.selection,
                onSelected: () => onSelected(plan.selection),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class PremiumPlanCard extends StatelessWidget {
  const PremiumPlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.onSelected,
  });
  final PremiumPlanPresentation plan;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Semantics(
          selected: selected,
          button: true,
          label:
              '${plan.title}${plan.badge == null ? '' : ', recommended'} plan',
          child: Material(
            key: ValueKey('premium-plan-${plan.selection.name}'),
            color: selected
                ? Color.alphaBlend(
                    colors.primary.withValues(alpha: .10),
                    colors.card,
                  )
                : colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: selected ? colors.primary : colors.border,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSelected,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.title,
                            style: premiumText(
                              context,
                              17,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ExcludeSemantics(
                          child: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 22,
                            color: selected
                                ? colors.primary
                                : colors.borderStrong,
                          ),
                        ),
                      ],
                    ),
                    Text.rich(
                      TextSpan(
                        text: plan.price,
                        style: premiumText(
                          context,
                          24,
                          weight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(
                            text: ' ${plan.suffix}',
                            style: premiumText(
                              context,
                              12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      plan.detail,
                      style: premiumText(
                        context,
                        13,
                        color: plan.selection == PremiumPlanSelection.yearly
                            ? colors.primary
                            : colors.textSecondary,
                        weight: plan.selection == PremiumPlanSelection.yearly
                            ? FontWeight.w800
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (plan.badge != null)
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plan.badge!,
                  style: premiumText(
                    context,
                    11,
                    weight: FontWeight.w800,
                    color: colors.buttonPrimaryText,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PremiumFooter extends StatelessWidget {
  const PremiumFooter({super.key, required this.onRestore});
  final VoidCallback onRestore;
  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    final linkStyle = premiumText(
      context,
      12,
      color: colors.primary,
    ).copyWith(decoration: TextDecoration.underline);
    return Column(
      spacing: 6,
      children: [
        TextButton(
          key: const ValueKey('premium-restore'),
          onPressed: onRestore,
          style: TextButton.styleFrom(
            foregroundColor: colors.textSecondary,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: premiumText(
              context,
              13,
              weight: FontWeight.w700,
            ).copyWith(decoration: TextDecoration.underline),
          ),
          child: const Text('Restore purchases'),
        ),
        Text(
          'Auto-renewable. Cancel anytime.',
          style: premiumText(context, 12, color: colors.textMuted),
        ),
        // TODO(legal): Wire approved destinations when available. Profile's
        // Terms/Privacy entries are placeholders; do not invent production URLs.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Terms', style: linkStyle),
              TextSpan(
                text: '   |   ',
                style: premiumText(context, 12, color: colors.textMuted),
              ),
              TextSpan(text: 'Privacy', style: linkStyle),
            ],
          ),
        ),
      ],
    );
  }
}
