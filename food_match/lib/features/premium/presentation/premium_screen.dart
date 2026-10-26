import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/premium_purchase.dart';
import '../logic/premium_purchase_coordinator.dart';
import '../logic/premium_provider.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/notification_theme.dart';
import '../../../core/utils/food_match_notifications.dart';
import '../domain/premium_entry_point.dart';
import 'premium_plan_presentation.dart';
import 'widgets/compact_premium_widgets.dart';
import 'widgets/premium_food_background.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({
    super.key,
    this.entryPoint = PremiumEntryPoint.overview,
    this.purchaseCoordinator = const UnavailablePremiumPurchaseCoordinator(),
  });
  final PremiumEntryPoint entryPoint;
  final PremiumPurchaseCoordinator purchaseCoordinator;
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  PremiumPlanSelection _selection = PremiumPlanSelection.yearly;

  late final PremiumPurchaseController _purchases = PremiumPurchaseController(
    coordinator: widget.purchaseCoordinator,
    refreshEntitlements: () => context.read<PremiumProvider>().forceRefresh(),
  );
  List<PremiumStoreProduct> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await widget.purchaseCoordinator.loadProducts();
      if (mounted) setState(() => _products = products);
    } catch (_) {
      // Store outages keep the marketing fallback visible.
    }
  }

  Future<void> _operate({bool restore = false}) async {
    _purchases.selection = _selection == PremiumPlanSelection.monthly
        ? PremiumProduct.monthly
        : PremiumProduct.yearly;
    final result = await (restore
        ? _purchases.restore()
        : _purchases.purchase());
    if (!mounted || result.message == null) return;
    FoodMatchNotifications.show(
      context,
      type: FoodMatchNotificationType.info,
      title: result.message!,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.fmColors.background,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const PremiumFoodBackground(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final compact = constraints.maxHeight < 820;
              final dense = constraints.maxWidth < 380 &&
                  scale > 1.1 && constraints.maxHeight < 800;
              final fallback =
                  constraints.maxHeight < 640 ||
                  (scale > 1.3 && constraints.maxHeight < 800) ||
                  scale > 1.6;
              final content = Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: fallback ? MainAxisSize.min : MainAxisSize.max,
                  spacing: compact ? (scale > 1.1 ? 2 : 10) : 16,
                  children: [
                    PremiumHero(
                      crownHeight: dense ? 48 : (compact ? 110 : 120),
                      compact: dense,
                    ),
                    PremiumBenefitsCard(compact: dense),
                    PremiumPlansSection(
                      selection: _selection,
                      products: _products,
                      onSelected: (value) => setState(() => _selection = value),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('premium-cta'),
                        onPressed: () => _operate(),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              context.fmColors.buttonPrimaryBackground,
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
                          PremiumPlanPresentation.forSelection(
                            _selection,
                            _products,
                          ).cta,
                        ),
                      ),
                    ),
                    PremiumFooter(onRestore: () => _operate(restore: true)),
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
      ],
    ),
  );
}
