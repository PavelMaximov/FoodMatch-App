import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/shopping_list_item.dart';
import '../../logic/shopping_list_provider.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    final ShoppingListProvider provider = context.watch<ShoppingListProvider>();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
        ),
        title: Text(
          'Grocery list',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 30,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: <Widget>[
              _ProgressRow(provider: provider),
              const SizedBox(height: 16),
              Expanded(
                child: provider.items.isEmpty
                    ? const _EmptyState()
                    : _ShoppingItems(provider: provider),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: FloatingActionButton(
          heroTag: 'shopping-list-add',
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            barrierColor: colors.modalBarrier,
            builder: (_) => ChangeNotifierProvider<ShoppingListProvider>.value(
              value: provider,
              child: const _AddProductSheet(),
            ),
          ),
          backgroundColor: colors.primary,
          foregroundColor: colors.buttonPrimaryText,
          elevation: 4,
          highlightElevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 34),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.provider});

  final ShoppingListProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'Total products: ',
              children: <InlineSpan>[
                TextSpan(
                  text: '${provider.checkedCount}/${provider.items.length}',
                  style: TextStyle(color: colors.primary),
                ),
              ],
            ),
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        _SmallAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Reset completed products',
          onPressed: provider.checkedCount == 0 ? null : provider.resetChecked,
        ),
        const SizedBox(width: 8),
        _SmallAction(
          icon: Icons.delete_rounded,
          tooltip: 'Clear grocery list',
          onPressed: provider.items.isEmpty ? null : () => _confirmClear(context),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final colors = context.fmColors;
    final bool? clear = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: colors.modalBackground,
        title: Text('Clear grocery list?', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'This will remove all products from your grocery list.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear')),
        ],
      ),
    );
    if (clear == true) await provider.clearAll();
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    return SizedBox.square(
      dimension: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: colors.textPrimary,
        disabledColor: colors.textMuted,
        style: IconButton.styleFrom(
          backgroundColor: colors.surface,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _ShoppingItems extends StatelessWidget {
  const _ShoppingItems({required this.provider});

  final ShoppingListProvider provider;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 92),
      itemCount: provider.items.length,
      onReorder: provider.reorder,
      itemBuilder: (BuildContext context, int index) {
        final ShoppingListItem item = provider.items[index];
        return _ShoppingRow(key: ValueKey<String>(item.id), item: item, index: index);
      },
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.item, required this.index, super.key});

  final ShoppingListItem item;
  final int index;

  String get quantityLabel {
    if (item.quantity == null) return '';
    if (item.measure == null) return item.quantity!;
    final bool spaced = item.measure == 'pcs' || item.measure == 'pack';
    return '${item.quantity}${spaced ? ' ' : ''}${item.measure}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    return SizedBox(
      height: 58,
      child: Row(
        children: <Widget>[
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.drag_indicator_rounded, size: 20, color: colors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: item.checked ? colors.textMuted : colors.textPrimary,
                decoration: item.checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              quantityLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.nunito(fontSize: 14, color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () => context.read<ShoppingListProvider>().toggleChecked(item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: item.checked ? colors.primary : Colors.transparent,
                border: Border.all(color: item.checked ? colors.primary : colors.borderStrong),
                borderRadius: BorderRadius.circular(5),
              ),
              child: item.checked
                  ? Icon(Icons.check_rounded, size: 18, color: colors.buttonPrimaryText)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Your grocery list is empty',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Add ingredients from a recipe or add a product manually.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet();

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  static const List<String> _measures = <String>[
    'kg', 'g', 'l', 'ml', 'pcs', 'tbsp', 'tsp', 'cup', 'pack',
  ];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _measure;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: colors.modalBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text('Add product', style: AppTextStyles.sectionHeader.copyWith(fontSize: 24, color: colors.textPrimary))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: colors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(context, '*Product name'),
                  validator: (String? value) => value == null || value.trim().isEmpty ? 'Product name is required' : null,
                ),
                const SizedBox(height: 22),
                Text('Add details', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _decoration(context, 'Enter quantity'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _measure,
                        decoration: _decoration(context, 'Measure'),
                        dropdownColor: colors.surface,
                        items: _measures.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                        onChanged: (String? value) => setState(() => _measure = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.buttonPrimaryText,
                      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('Add +', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(BuildContext context, String hint) {
    final colors = context.fmColors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textMuted),
      filled: true,
      fillColor: colors.inputBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.inputFocusedBorder)),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await context.read<ShoppingListProvider>().addManualItem(
          name: _nameController.text,
          quantity: _quantityController.text,
          measure: _measure,
        );
    if (mounted) Navigator.pop(context);
  }
}
