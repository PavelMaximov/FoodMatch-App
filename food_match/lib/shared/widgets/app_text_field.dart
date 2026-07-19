import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/theme_extensions.dart';

class AppTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool required;
  final int maxLines;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.required = false,
    this.maxLines = 1,
    this.suffixIcon,
    this.autofillHints,
  });

String? _validate(String? value) {
    if (required && (value == null || value.trim().isEmpty)) {
      return 'Это поле обязательно для заполнения';
    }
    return validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return TextFormField(
      style: TextStyle(color: colors.textPrimary),
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: _validate,
      maxLines: maxLines,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textMuted),
        filled: true,
        fillColor: colors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.inputFocusedBorder, width: 2),
        ),
        suffixIcon: suffixIcon,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.error),
        ),
      ),
    );
  }
}
