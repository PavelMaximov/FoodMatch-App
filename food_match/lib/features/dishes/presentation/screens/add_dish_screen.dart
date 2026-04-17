import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/repositories/dish_repository.dart';
import '../../../../data/repositories/upload_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../../shared/widgets/app_button.dart';

class AddDishScreen extends StatefulWidget {
  const AddDishScreen({super.key});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _cookTimeController = TextEditingController();
  final TextEditingController _stepInputController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingMyDishes = false;
  List<Dish> _myDishes = <Dish>[];

  String? _selectedCuisine;
  String? _selectedMood;
  int _selectedServings = 2;
  String _imageUrl = '';
  final List<_IngredientInput> _ingredients = <_IngredientInput>[];
  final List<String> _steps = <String>[];

  static const List<String> _moods = <String>[
    'Comfort',
    'Romantic',
    'Light',
    'Festive',
    'Quick',
    'Healthy'
  ];

  static const List<String> _measureUnits = <String>[
    'piece',
    'as needed',
    'g',
    'kg',
    'ml',
    'l',
    'teaspoon',
    'tablespoon',
    'to taste',
    'cup',
    'pinch',
    'slice',
    'clove',
    'oz',
    'lb',
  ];

  static const List<String> _cuisines = <String>[
    'American',
    'Italian',
    'Mexican',
    'Indian',
    'Chinese',
    'Japanese',
    'Thai',
    'French',
    'Mediterranean',
    'Turkish',
    'Greek',
    'Spanish',
    'Korean',
    'Vietnamese',
    'Middle Eastern'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyDishes();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cookTimeController.dispose();
    _stepInputController.dispose();
    super.dispose();
  }

  Future<void> _loadMyDishes() async {
    setState(() => _isLoadingMyDishes = true);
    try {
      final DishRepository dishRepository = context.read<DishRepository>();
      final List<Dish> dishes = await dishRepository.getMyCustomDishes();
      _myDishes = dishes;
    } catch (_) {
      _myDishes = <Dish>[];
    } finally {
      if (mounted) {
        setState(() => _isLoadingMyDishes = false);
      }
    }
  }

  Future<List<String>> _searchIngredients(String query) async {
    try {
      return await context.read<DishRepository>().searchIngredients(query);
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final UploadRepository uploadRepository = context.read<UploadRepository>();
      final String url = await uploadRepository.uploadImage(File(image.path));
      _imageUrl = url;
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showError(context, AppStrings.unableToUploadImage);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openIngredientSheet({int? index}) async {
    final _IngredientInput? ingredient = await showModalBottomSheet<_IngredientInput>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (_) => _AddIngredientSheet(
        searchIngredients: _searchIngredients,
        units: _measureUnits,
        initialIngredient: index == null ? null : _ingredients[index],
      ),
    );

    if (ingredient == null) return;
    setState(() {
      if (index == null) {
        _ingredients.add(ingredient);
      } else {
        _ingredients[index] = ingredient;
      }
    });
  }

  Future<void> _submit() async {
    final bool isValidForm = _formKey.currentState?.validate() ?? false;
    if (!isValidForm || _selectedCuisine == null || _selectedMood == null || _ingredients.isEmpty) {
      SnackBarUtils.showError(context, 'Please complete all required fields');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final DishRepository dishRepository = context.read<DishRepository>();

      await dishRepository.createCustomDish(
        title: _titleController.text.trim(),
        cuisine: _selectedCuisine!,
        mood: _selectedMood!,
        ingredients: _ingredients
            .map((item) => <String, String>{
                  'name': item.name,
                  'quantity': item.quantity,
                  'unit': item.unit,
                })
            .toList(),
        cookTime: int.tryParse(_cookTimeController.text.trim()) ?? 0,
        servings: _selectedServings,
        instructions: _steps,
        imageUrl: _imageUrl,
      );

      _formKey.currentState?.reset();
      _titleController.clear();
      _cookTimeController.clear();
      _stepInputController.clear();
      setState(() {
        _selectedCuisine = null;
        _selectedMood = null;
        _selectedServings = 2;
        _ingredients.clear();
        _steps.clear();
        _imageUrl = '';
      });

      await _loadMyDishes();
      if (mounted) {
        SnackBarUtils.showSuccess(context, AppStrings.dishAdded);
      }
    } on ApiException catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showError(context, AppStrings.failedToAddDish);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteDish(Dish dish) async {
    try {
      await context.read<DishRepository>().deleteMyDish(dish.id);
      await _loadMyDishes();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Dish deleted');
      }
    } on ApiException catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to delete dish');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  AppStrings.addYourDish,
                  style: GoogleFonts.pacifico(
                    fontSize: 38,
                    color: AppColors.textPrimary,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.addDishDesc,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 15.5),
                ),
                const SizedBox(height: AppDimensions.paddingL),
                _RequiredLabel(text: 'Enter title of your dish'),
                const SizedBox(height: 8),
                _AppInput(
                  controller: _titleController,
                  hint: 'Name of the dish',
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _RequiredLabel(text: 'Choose country of your dish'),
                const SizedBox(height: 8),
                _AppSelect<String>(
                  value: _selectedCuisine,
                  hint: 'Cuisine',
                  items: _cuisines,
                  onChanged: (String? value) => setState(() => _selectedCuisine = value),
                ),
                const SizedBox(height: 14),
                _RequiredLabel(text: 'Choose mood of your dish'),
                const SizedBox(height: 8),
                _AppSelect<String>(
                  value: _selectedMood,
                  hint: 'Mood',
                  items: _moods,
                  onChanged: (String? value) => setState(() => _selectedMood = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Serving size', style: AppTextStyles.bodyLarge),
                          const SizedBox(height: 8),
                          _ServingSizeSelect(
                            value: _selectedServings,
                            onChanged: (int value) => setState(() => _selectedServings = value),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Cooking time', style: AppTextStyles.bodyLarge),
                          const SizedBox(height: 8),
                          _AppInput(
                            controller: _cookTimeController,
                            hint: '30 min.',
                            keyboardType: TextInputType.number,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _RequiredLabel(text: 'Ingredients'),
                const SizedBox(height: 8),
                if (_ingredients.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ingredients.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final _IngredientInput ingredient = entry.value;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFBFB7B2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${ingredient.name} ${ingredient.quantity} ${ingredient.unit}'.trim(),
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _openIngredientSheet(index: index),
                              child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _ingredients.removeAt(index);
                                });
                              },
                              child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openIngredientSheet(),
                  child: Text(
                    '+ Add ingredients',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cooking instructions (optional)',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _AppInput(
                        controller: _stepInputController,
                        hint: '+ Add a cooking step',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final String value = _stepInputController.text.trim();
                        if (value.isEmpty) return;
                        setState(() {
                          _steps.add(value);
                        });
                        _stepInputController.clear();
                      },
                      icon: const Icon(Icons.add_circle, color: AppColors.primary),
                    )
                  ],
                ),
                if (_steps.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ..._steps.asMap().entries.map(
                        (entry) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD6CDC8)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('${entry.key + 1}. ', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                              Expanded(child: Text(entry.value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary))),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _steps.removeAt(entry.key);
                                  });
                                },
                                child: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 18),
                              )
                            ],
                          ),
                        ),
                      )
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _isSubmitting ? null : _pickImage,
                  child: Container(
                    width: 210,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.add, color: AppColors.textHint),
                        Text(
                          'Add image (optional)',
                          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_imageUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: ImageUtils.getImageUrl(_imageUrl),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  text: AppStrings.saveToDeck,
                  icon: Icons.add_circle,
                  onPressed: _submit,
                  isLoading: _isSubmitting,
                ),
                const SizedBox(height: AppDimensions.paddingXL),
                Divider(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  height: 1,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                Center(
                  child: Text(
                    AppStrings.dishesYouAdded,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textHint),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                if (_isLoadingMyDishes)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingL),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (_myDishes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
                    child: Center(
                      child: Text(
                        AppStrings.noDishesAdded,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _myDishes.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Dish dish = _myDishes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                        child: _MyDishCard(
                          dish: dish,
                          onDelete: () => _deleteDish(dish),
                          onOpen: () => context.push('/recipe-detail/${dish.id}', extra: dish),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: AppDimensions.paddingL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyLarge,
        children: <InlineSpan>[
          const TextSpan(text: '* ', style: TextStyle(color: AppColors.error)),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

class _AppInput extends StatelessWidget {
  const _AppInput({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.textHint),
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFB7B2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFB7B2)),
        ),
      ),
    );
  }
}

class _AppSelect<T> extends StatelessWidget {
  const _AppSelect({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  final T? value;
  final List<T> items;
  final String hint;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFB7B2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textHint)),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(item.toString(), style: AppTextStyles.bodyLarge),
                  ))
              .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ),
    );
  }
}

class _ServingSizeSelect extends StatelessWidget {
  const _ServingSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFB7B2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          onChanged: (int? next) {
            if (next != null) onChanged(next);
          },
          icon: const Icon(Icons.keyboard_arrow_down),
          items: List<int>.generate(10, (index) => index + 1)
              .map((item) => DropdownMenuItem<int>(
                    value: item,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.groups_2_outlined, size: 16, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Text('$item', style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _IngredientInput {
  const _IngredientInput({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final String quantity;
  final String unit;
}

class _AddIngredientSheet extends StatefulWidget {
  const _AddIngredientSheet({
    required this.searchIngredients,
    required this.units,
    this.initialIngredient,
  });

  final Future<List<String>> Function(String query) searchIngredients;
  final List<String> units;
  final _IngredientInput? initialIngredient;

  @override
  State<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends State<_AddIngredientSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String? _unit;
  String? _selectedIngredient;
  List<String> _results = <String>[];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    final _IngredientInput? initial = widget.initialIngredient;
    if (initial != null) {
      _searchController.text = initial.name;
      _selectedIngredient = initial.name;
      _quantityController.text = initial.quantity;
      _unit = initial.unit.isEmpty ? null : initial.unit;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String value) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;

      setState(() {
        _isSearching = true;
      });

      final List<String> searchResults = await widget.searchIngredients(value);
      if (!mounted) return;

      setState(() {
        _results = searchResults;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 22, bottom: bottomInset + 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                widget.initialIngredient == null ? 'Add ingredient' : 'Edit ingredient',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 19),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          _AppInput(
            controller: _searchController,
            hint: 'Search ingredient',
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: _isSearching ? 32 : (_results.isNotEmpty ? 120 : 0),
            child: _isSearching
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : (_results.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String result = _results[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                            title: Text(result, style: AppTextStyles.bodyMedium),
                            onTap: () {
                              setState(() {
                                _selectedIngredient = result;
                                _searchController.text = result;
                                _results = <String>[];
                              });
                            },
                          );
                        },
                      )),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _AppInput(
                  controller: _quantityController,
                  hint: 'Enter quantity',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AppSelect<String>(
                  value: _unit,
                  hint: 'Measure',
                  items: widget.units,
                  onChanged: (String? value) => setState(() => _unit = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 148,
              child: AppButton(
                text: widget.initialIngredient == null ? 'Add  +' : 'Update',
                onPressed: () {
                  final String ingredientName = (_selectedIngredient ?? _searchController.text).trim();
                  if (ingredientName.isEmpty) return;

                  Navigator.of(context).pop(
                    _IngredientInput(
                      name: ingredientName,
                      quantity: _quantityController.text.trim(),
                      unit: _unit ?? '',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDishCard extends StatelessWidget {
  const _MyDishCard({
    required this.dish,
    required this.onDelete,
    required this.onOpen,
  });

  final Dish dish;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFBFB7B2)),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  bottomLeft: Radius.circular(26),
                ),
                child: CachedNetworkImage(
                  imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                  width: 115,
                  height: 120,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(
                    width: 115,
                    height: 120,
                    child: ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              dish.name,
                              style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete, color: AppColors.error),
                          )
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        children: <String>[
                          if (dish.cuisine.isNotEmpty) dish.cuisine,
                          if (dish.mood.isNotEmpty) dish.mood.first,
                        ]
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFF888888)),
                                ),
                                child: Text(tag, style: AppTextStyles.bodySmall),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${dish.cookTime} min.',
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.groups_2_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${dish.servings.isEmpty ? '2' : dish.servings} servings',
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
