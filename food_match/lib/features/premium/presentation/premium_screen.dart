import 'package:flutter/material.dart';

import '../domain/premium_entry_point.dart';
import 'premium_plan_presentation.dart';
import 'widgets/premium_widgets.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PremiumPalette.background,
    body: SafeArea(
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                children: [
                  PremiumHero(entryPoint: widget.entryPoint),
                  const SizedBox(height: 28),
                  const PremiumBenefitsCard(),
                  const SizedBox(height: 20),
                  PremiumPlansSection(
                    selection: _selection,
                    onSelected: (value) => setState(() => _selection = value),
                  ),
                  const SizedBox(height: 28),
                  const PremiumLegalDisclaimer(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
