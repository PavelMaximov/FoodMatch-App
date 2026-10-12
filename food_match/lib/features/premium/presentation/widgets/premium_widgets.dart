import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/premium_entry_point.dart';
import '../premium_plan_presentation.dart';

/// Deliberately isolated from the application's light/dark theme.
class PremiumPalette {
  const PremiumPalette._();

  static const background = Color(0xFF2D2825);
  static const card = Color(0xFF3A322D);
  static const border = Color(0xFF5B5048);
  static const text = Color(0xFFF1E9E3);
  static const muted = Color(0xFFB49D90);
  static const orange = AppColors.primary;
  static const amber = Color(0xFFFFAC16);
}

TextStyle _body(double size, {Color? color, FontWeight? weight}) =>
    GoogleFonts.nunito(
      fontSize: size,
      color: color ?? PremiumPalette.text,
      fontWeight: weight ?? FontWeight.w400,
      height: 1.15,
    );

class PremiumHero extends StatelessWidget {
  const PremiumHero({super.key, required this.entryPoint});

  final PremiumEntryPoint entryPoint;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 150,
        child: Stack(
          children: [
            Center(
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 214,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/profile/premium_crown_icon.png',
                        width: 140,
                        height: 148,
                        fit: BoxFit.contain,
                      ),
                      const Positioned(
                        left: 18,
                        top: 12,
                        child: _Sparkle(size: 22),
                      ),
                      const Positioned(
                        right: 6,
                        top: 20,
                        child: _Sparkle(size: 26),
                      ),
                      const Positioned(
                        left: 0,
                        top: 62,
                        child: _Sparkle(size: 16),
                      ),
                      const Positioned(
                        right: 17,
                        bottom: 28,
                        child: _Sparkle(size: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                key: const ValueKey('premium-close'),
                tooltip: 'Close Premium',
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF48423E),
                  foregroundColor: PremiumPalette.muted,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.close, size: 22),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Semantics(
        header: true,
        child: Text(
          'Unlock Premium',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: PremiumPalette.text,
            height: 1.1,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Semantics(
        // Preserve contextual routing information without a second hero title.
        label: entryPoint.subtitle,
        child: Text(
          'Get the full FoodMatch experience\nand make meal planning even easier',
          textAlign: TextAlign.center,
          style: _body(17, color: PremiumPalette.muted),
        ),
      ),
    ],
  );
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _SparklePainter());
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w * .6, h * .4, w, h / 2)
      ..quadraticBezierTo(w * .6, h * .6, w / 2, h)
      ..quadraticBezierTo(w * .4, h * .6, 0, h / 2)
      ..quadraticBezierTo(w * .4, h * .4, w / 2, 0);
    canvas.drawPath(path, Paint()..color = PremiumPalette.amber);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}

class PremiumBenefitsCard extends StatelessWidget {
  const PremiumBenefitsCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PremiumPalette.card,
      border: Border.all(color: PremiumPalette.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      children: [
        PremiumBenefitRow(
          icon: Icons.ad_units_outlined,
          title: 'No ads',
          description: 'Enjoy a distraction-free experience',
        ),
        SizedBox(height: 22),
        PremiumBenefitRow(
          icon: Icons.filter_alt_outlined,
          title: 'Advanced filters',
          description:
              'Filter by calories, cook time, difficulty, ingredients and more',
        ),
        SizedBox(height: 22),
        PremiumBenefitRow(
          icon: Icons.add_circle_outline,
          title: 'Unlimited custom dishes',
          description: 'Add as many of your own recipes as you like',
        ),
        SizedBox(height: 22),
        PremiumBenefitRow(
          icon: Icons.history,
          title: 'Session history',
          description: 'Keep track of your past cooking sessions',
        ),
        SizedBox(height: 22),
        PremiumBenefitRow(
          icon: Icons.shopping_cart_outlined,
          title: 'Shopping lists',
          description:
              'Add recipe ingredients, merge duplicates and share with your pair',
        ),
      ],
    ),
  );
}

class PremiumBenefitRow extends StatelessWidget {
  const PremiumBenefitRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: PremiumPalette.orange,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 23, color: Colors.white),
        ),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _body(15, weight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(description, style: _body(13, color: PremiumPalette.muted)),
          ],
        ),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final stacked = constraints.maxWidth < 300 || scale > 1.35;
      final plans = [
        for (final plan in const [
          PremiumPlanPresentation.monthly,
          PremiumPlanPresentation.yearly,
        ])
          PremiumPlanCard(
            stretch: !stacked,
            plan: plan,
            selected: selection == plan.selection,
            onChoose: () => onSelected(plan.selection),
          ),
      ];
      if (stacked) {
        return Column(
          key: const ValueKey('premium-plans-stacked'),
          children: [plans.first, const SizedBox(height: 16), plans.last],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: plans.first,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: plans.last,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PremiumPlanCard extends StatelessWidget {
  const PremiumPlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.onChoose,
    this.stretch = false,
  });
  final PremiumPlanPresentation plan;
  final bool selected;
  final VoidCallback onChoose;
  final bool stretch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Semantics(
          selected: selected,
          label: '${plan.title}${plan.recommended ? ', recommended' : ''} plan',
          child: Container(
            key: ValueKey('premium-plan-${plan.selection.name}'),
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 16),
            decoration: BoxDecoration(
              color: PremiumPalette.card,
              gradient: plan.recommended
                  ? const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF74501C), PremiumPalette.card],
                    )
                  : null,
              border: Border.all(
                color: selected ? PremiumPalette.amber : PremiumPalette.border,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Text(plan.title, style: _body(15, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    text: plan.price,
                    style: _body(24, weight: FontWeight.w800),
                    children: [
                      TextSpan(
                        text: ' ${plan.billingSuffix}',
                        style: _body(13, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  plan.comparisonPrice ?? ' ',
                  style: _body(13, color: PremiumPalette.muted).copyWith(
                    decoration: plan.comparisonPrice == null
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 10),
                for (final benefit in plan.benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: plan.recommended
                                  ? const Color(0xFF704719)
                                  : const Color(0xFF595753),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: plan.recommended
                                  ? PremiumPalette.amber
                                  : PremiumPalette.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(benefit, style: _body(11))),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (stretch) const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: ValueKey('premium-choose-${plan.selection.name}'),
                    onPressed: onChoose,
                    style: TextButton.styleFrom(
                      backgroundColor: selected
                          ? PremiumPalette.orange
                          : Colors.transparent,
                      foregroundColor: selected
                          ? Colors.white
                          : PremiumPalette.orange,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      side: const BorderSide(
                        color: PremiumPalette.orange,
                        width: 2,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: _body(15, weight: FontWeight.w800),
                    ),
                    child: const Text('Choose'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (plan.badge != null)
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: PremiumPalette.orange,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Text(plan.badge!, style: _body(10, color: Colors.white)),
              ),
            ),
          ),
      ],
    ),
  );
}

class PremiumLegalDisclaimer extends StatelessWidget {
  const PremiumLegalDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final style = _body(11, color: PremiumPalette.muted).copyWith(height: 1.4);
    final legalStyle = style.copyWith(
      color: PremiumPalette.orange,
      decoration: TextDecoration.underline,
    );
    // TODO(legal): Wire spans to approved legal routes/URLs when available.
    // Profile's legal entries are placeholders too; do not invent destinations.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${PremiumPlanPresentation.yearly.trialDisclaimer}\n'),
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(text: 'Terms of Service', style: legalStyle),
          const TextSpan(text: ' and\n'),
          TextSpan(text: 'Privacy Policy', style: legalStyle),
          const TextSpan(text: '.'),
        ],
      ),
      style: style,
      textAlign: TextAlign.center,
    );
  }
}
