import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AppCenteredHeader extends StatelessWidget {
  const AppCenteredHeader({
    super.key,
    required this.title,
    required this.onBackTap,
  });

  final String title;
  final VoidCallback onBackTap;

  static const double iconSize = 40;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _HeaderBackButton(onTap: onBackTap),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.pageTitle.copyWith(fontSize: 34),
          ),
        ),
        const SizedBox(width: iconSize, height: iconSize),
      ],
    );
  }
}

class RecipeSearchFilterBar extends StatelessWidget {
  const RecipeSearchFilterBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isActive,
    required this.hasActiveFilters,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCloseOrClear,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isActive;
  final bool hasActiveFilters;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCloseOrClear;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: !isActive,
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search any recipe',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 15,
                  color: const Color(0xFFB8B1AE),
                ),
                prefixIcon: isActive
                    ? null
                    : const Icon(Icons.search, size: 18, color: Color(0xFF9B9491)),
                suffixIcon: isActive
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onCloseOrClear,
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textPrimary),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.only(
                  left: isActive ? 14 : 0,
                  right: 10,
                  top: 9,
                  bottom: 9,
                ),
                enabledBorder: _border(const Color(0xFFE7E0DD)),
                focusedBorder: _border(AppColors.primary),
              ),
            ),
          ),
        ),
        if (!isActive) ...<Widget>[
          const SizedBox(width: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onFilterTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasActiveFilters ? AppColors.primary : const Color(0xFFE7E0DD),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.tune,
                  size: 20,
                  color: hasActiveFilters ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.4),
      );
}

class RecentSearchBlock extends StatelessWidget {
  const RecentSearchBlock({
    super.key,
    required this.searches,
    required this.onClear,
    required this.onSelected,
  });

  final List<String> searches;
  final VoidCallback onClear;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Recent', style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child: Text(
                  'Clear',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final String query in searches)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: InkWell(
                onTap: () => onSelected(query),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.history, size: 16, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        query,
                        style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: const SizedBox(
        width: AppCenteredHeader.iconSize,
        height: AppCenteredHeader.iconSize,
        child: Icon(Icons.arrow_back, size: 24, color: AppColors.textPrimary),
      ),
    );
  }
}
