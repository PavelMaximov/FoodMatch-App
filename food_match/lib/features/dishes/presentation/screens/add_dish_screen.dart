import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/assets/app_empty_state_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/repositories/dish_repository.dart';
import '../../../../data/repositories/upload_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../swipes/logic/swipe_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/dish_compact_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/dish_taxonomy.dart';

class AddDishScreen extends StatefulWidget {
  const AddDishScreen({super.key});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _PendingDeletedDish {
  _PendingDeletedDish({
    required this.dish,
    required this.index,
    required this.repository,
  });

  final Dish dish;
  int index;
  final DishRepository repository;
  Timer? timer;
  bool isCommitted = false;
}

class _AddDishScreenState extends State<AddDishScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _cookTimeController = TextEditingController();
  final TextEditingController _stepInputController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingMyDishes = false;
  List<Dish> _myDishes = <Dish>[];
  final Map<String, _PendingDeletedDish> _pendingDeletedDishes =
      <String, _PendingDeletedDish>{};

  String? _selectedCuisine;
  String? _selectedMood;
  int? _selectedServings;
  File? _selectedImageFile;
  DishImageUploadResult? _uploadedDishImage;
  final List<_IngredientInput> _ingredients = <_IngredientInput>[];
  final List<String> _steps = <String>[];

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyDishes();
    });
  }

  @override
  void dispose() {
    final List<_PendingDeletedDish> pendingDeletes = _pendingDeletedDishes
        .values
        .toList(growable: false);
    _pendingDeletedDishes.clear();
    for (final _PendingDeletedDish pendingDelete in pendingDeletes) {
      pendingDelete.timer?.cancel();
      unawaited(_commitDeleteAfterDispose(pendingDelete));
    }
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
      _myDishes = dishes
          .where((Dish dish) => !_pendingDeletedDishes.containsKey(dish.id))
          .toList();
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

    setState(() {
      _selectedImageFile = File(image.path);
      _uploadedDishImage = null;
    });
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _uploadedDishImage = null;
    });
  }

  Future<void> _openIngredientSheet({int? index}) async {
    final _IngredientInput? ingredient =
        await showModalBottomSheet<_IngredientInput>(
          context: context,
          backgroundColor: context.fmColors.modalBackground,
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
    if (_isSubmitting) return;
    final bool isValidForm = _formKey.currentState?.validate() ?? false;
    if (!isValidForm) return;
    if (_selectedCuisine == null) {
      FoodMatchNotifications.show(
        context,
        type: FoodMatchNotificationType.warning,
        title: 'Choose a cuisine.',
      );
      return;
    }
    if (_selectedMood == null) {
      FoodMatchNotifications.show(
        context,
        type: FoodMatchNotificationType.warning,
        title: 'Choose a mood.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final DishRepository dishRepository = context.read<DishRepository>();
      DishImageUploadResult? imageUpload = _uploadedDishImage;

      if (_selectedImageFile != null && imageUpload == null) {
        try {
          imageUpload = await context
              .read<UploadRepository>()
              .uploadCustomDishImage(_selectedImageFile!);
          _uploadedDishImage = imageUpload;
        } on ApiException catch (_) {
          if (mounted) {
            FoodMatchNotifications.show(
              context,
              type: FoodMatchNotificationType.error,
              title: AppStrings.unableToUploadImage,
            );
          }
          return;
        } catch (_) {
          if (mounted) {
            FoodMatchNotifications.show(
              context,
              type: FoodMatchNotificationType.error,
              title: AppStrings.unableToUploadImage,
            );
          }
          return;
        }
      }

      await dishRepository.createCustomDish(
        title: _titleController.text.trim(),
        cuisine: _selectedCuisine!,
        mood: _selectedMood!,
        ingredients: _ingredients
            .map(
              (item) => <String, String>{
                'name': item.name,
                'quantity': item.quantity,
                'unit': item.unit,
              },
            )
            .toList(),
        cookTime: int.tryParse(_cookTimeController.text.trim()) ?? 0,
        servings: _selectedServings?.toString() ?? '',
        instructions: _steps,
        imageUrl: imageUpload?.imageUrl ?? '',
        imagePublicId: imageUpload?.imagePublicId,
      );

      _formKey.currentState?.reset();
      _titleController.clear();
      _cookTimeController.clear();
      _stepInputController.clear();
      setState(() {
        _selectedCuisine = null;
        _selectedMood = null;
        _selectedServings = null;
        _ingredients.clear();
        _steps.clear();
        _selectedImageFile = null;
        _uploadedDishImage = null;
      });

      _invalidateSwipeDeckCacheIfAvailable();

      await _loadMyDishes();
      if (mounted) {
        FoodMatchNotifications.show(
          context,
          type: FoodMatchNotificationType.success,
          title: AppStrings.dishAdded,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        FoodMatchNotifications.show(
          context,
          type: FoodMatchNotificationType.error,
          title: ErrorMessages.fromApiException(
            e,
            fallback: AppStrings.failedToAddDish,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        FoodMatchNotifications.show(
          context,
          type: FoodMatchNotificationType.error,
          title: AppStrings.failedToAddDish,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _invalidateSwipeDeckCacheIfAvailable() {
    try {
      context.read<SwipeProvider>().clearPreparedDeck();
    } catch (_) {
      // Add Dish can be used without an active swipe provider in some test/shell contexts.
    }
  }

  void _deleteDish(Dish dish) {
    if (_pendingDeletedDishes.containsKey(dish.id)) return;

    final int index = _myDishes.indexWhere(
      (Dish currentDish) => currentDish.id == dish.id,
    );
    if (index < 0) return;

    int originalIndex = index;
    for (final _PendingDeletedDish pendingDelete
        in _pendingDeletedDishes.values) {
      if (pendingDelete.index <= originalIndex) originalIndex++;
    }

    final _PendingDeletedDish pendingDelete = _PendingDeletedDish(
      dish: dish,
      index: originalIndex,
      repository: context.read<DishRepository>(),
    );
    _pendingDeletedDishes[dish.id] = pendingDelete;
    pendingDelete.timer = Timer(
      const Duration(seconds: 6),
      () => _commitPendingDelete(dish.id),
    );

    setState(() => _myDishes.removeAt(index));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    FoodMatchNotifications.show(
      context,
      type: FoodMatchNotificationType.destructive,
      title: 'Dish deleted',
      message: '${dish.name} was removed',
      actionLabel: 'Undo',
      onAction: () => _undoDeleteDish(dish.id),
    );
  }

  void _undoDeleteDish(String dishId) {
    final _PendingDeletedDish? pendingDelete = _pendingDeletedDishes.remove(
      dishId,
    );
    if (pendingDelete == null || pendingDelete.isCommitted) return;

    pendingDelete.timer?.cancel();
    if (!mounted || _myDishes.any((Dish dish) => dish.id == dishId)) return;

    setState(() {
      final int safeIndex = _visibleIndexFor(pendingDelete);
      _myDishes.insert(safeIndex, pendingDelete.dish);
    });
  }

  Future<void> _commitPendingDelete(String dishId) async {
    final _PendingDeletedDish? pendingDelete = _pendingDeletedDishes[dishId];
    if (pendingDelete == null || pendingDelete.isCommitted) return;

    pendingDelete.isCommitted = true;
    pendingDelete.timer?.cancel();
    try {
      await pendingDelete.repository.deleteMyDish(dishId);
      _pendingDeletedDishes.remove(dishId);
      for (final _PendingDeletedDish other in _pendingDeletedDishes.values) {
        if (other.index > pendingDelete.index) other.index--;
      }
      if (mounted) _invalidateSwipeDeckCacheIfAvailable();
    } on ApiException catch (e) {
      _rollbackFailedDelete(
        pendingDelete,
        ErrorMessages.fromApiException(e, fallback: 'Please try again.'),
      );
    } catch (_) {
      _rollbackFailedDelete(pendingDelete, 'Please try again.');
    }
  }

  void _rollbackFailedDelete(
    _PendingDeletedDish pendingDelete,
    String message,
  ) {
    _pendingDeletedDishes.remove(pendingDelete.dish.id);
    if (!mounted) return;

    if (!_myDishes.any((Dish dish) => dish.id == pendingDelete.dish.id)) {
      setState(() {
        final int safeIndex = _visibleIndexFor(pendingDelete);
        _myDishes.insert(safeIndex, pendingDelete.dish);
      });
    }
    FoodMatchNotifications.show(
      context,
      type: FoodMatchNotificationType.error,
      title: 'Could not delete dish',
      message: message,
    );
  }

  Future<void> _commitDeleteAfterDispose(
    _PendingDeletedDish pendingDelete,
  ) async {
    if (pendingDelete.isCommitted) return;
    pendingDelete.isCommitted = true;
    try {
      await pendingDelete.repository.deleteMyDish(pendingDelete.dish.id);
    } catch (_) {
      // A failed delete remains on the backend and will reappear on the next load.
    }
  }

  int _visibleIndexFor(_PendingDeletedDish pendingDelete) {
    final int hiddenBefore = _pendingDeletedDishes.values
        .where((_PendingDeletedDish other) => other.index < pendingDelete.index)
        .length;
    final int visibleIndex = pendingDelete.index - hiddenBefore;
    return visibleIndex < _myDishes.length ? visibleIndex : _myDishes.length;
  }

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 10),
                Text(
                  AppStrings.addYourDish,
                  style: AppTextStyles.pageTitle.copyWith(
                    height: 0.95,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.addDishDesc,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 15.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingL),
                const _RequiredLabel(text: 'Enter title of your dish'),
                const SizedBox(height: 8),
                _AppInput(
                  controller: _titleController,
                  hint: 'Name of the dish',
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty)
                      return 'Dish name is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const _RequiredLabel(text: 'Choose country of your dish'),
                const SizedBox(height: 8),
                _AppSelect<String>(
                  value: _selectedCuisine,
                  hint: 'Cuisine',
                  items: DishTaxonomy.cuisines,
                  itemLabel: DishTaxonomy.labelFor,
                  onChanged: (String? value) =>
                      setState(() => _selectedCuisine = value),
                ),
                const SizedBox(height: 14),
                const _RequiredLabel(text: 'Choose mood of your dish'),
                const SizedBox(height: 8),
                _AppSelect<String>(
                  value: _selectedMood,
                  hint: 'Mood',
                  items: DishTaxonomy.moods,
                  itemLabel: DishTaxonomy.labelFor,
                  onChanged: (String? value) =>
                      setState(() => _selectedMood = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Serving size',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ServingSizeSelect(
                            value: _selectedServings,
                            onChanged: (int? value) =>
                                setState(() => _selectedServings = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _RequiredLabel(text: 'Cooking time'),
                          const SizedBox(height: 8),
                          _AppInput(
                            controller: _cookTimeController,
                            hint: '30 min.',
                            keyboardType: TextInputType.number,
                            validator: (String? value) {
                              final String trimmed = (value ?? '').trim();
                              final int? minutes = int.tryParse(trimmed);
                              if (trimmed.isEmpty ||
                                  minutes == null ||
                                  minutes <= 0) {
                                return 'Enter a valid cooking time.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Ingredients (optional)',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_ingredients.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ingredients.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final _IngredientInput ingredient = entry.value;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.chipBackground,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.chipBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${ingredient.name} ${ingredient.quantity} ${ingredient.unit}'
                                  .trim(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _openIngredientSheet(index: index),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _ingredients.removeAt(index);
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: colors.textMuted,
                              ),
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
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cooking instructions (optional)',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                  ),
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
                      icon: Icon(Icons.add_circle, color: colors.primary),
                    ),
                  ],
                ),
                if (_steps.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ..._steps.asMap().entries.map(
                    (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${entry.key + 1}. ',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _steps.removeAt(entry.key);
                              });
                            },
                            child: Icon(
                              Icons.delete_outline,
                              color: colors.textMuted,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _isSubmitting ? null : _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: _selectedImageFile == null ? 96 : 160,
                    decoration: BoxDecoration(
                      color: colors.imageFallbackBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _selectedImageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: colors.textMuted,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Add dish photo',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                              Text(
                                'Optional',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                Image.file(
                                  _selectedImageFile!,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Material(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Remove image',
                                      onPressed: _isSubmitting
                                          ? null
                                          : _removeSelectedImage,
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: AppStrings.saveToDeck,
                  icon: Icons.add_circle,
                  onPressed: _isSubmitting ? null : _submit,
                  isLoading: _isSubmitting,
                ),
                const SizedBox(height: AppDimensions.paddingXL),
                Divider(color: colors.divider, height: 1),
                const SizedBox(height: AppDimensions.paddingM),
                Center(
                  child: Text(
                    AppStrings.dishesYouAdded,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                if (_isLoadingMyDishes)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.paddingL,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                  )
                else if (_myDishes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(
                      bottom: AppDimensions.paddingL,
                    ),
                    child: EmptyState(
                      icon: Icons.add_circle_outline,
                      imageAsset: AppEmptyStateAssets.emptyCustomDishes,
                      title: 'No custom dishes yet',
                      subtitle: 'Add your own dish and use it in your swipes.',
                      
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
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.paddingS,
                        ),
                        child: DishCompactCard(
                          dish: dish,
                          onTap: () => context.push(
                            '/recipe-detail/${dish.id}',
                            extra: dish,
                          ),
                          trailing: DishCompactCardIconButton(
                            icon: Icons.delete_outline,
                            tooltip: 'Delete dish',
                            color: colors.error,
                            backgroundColor: colors.cardElevated,
                            onTap: () => _deleteDish(dish),
                          ),
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
        style: AppTextStyles.bodyLarge.copyWith(
          color: context.fmColors.textPrimary,
        ),
        children: <InlineSpan>[
          TextSpan(
            text: '* ',
            style: TextStyle(color: context.fmColors.error),
          ),
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
      style: TextStyle(color: context.fmColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyLarge.copyWith(
          color: context.fmColors.textMuted,
        ),
        fillColor: context.fmColors.inputBackground,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.fmColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.fmColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.fmColors.inputFocusedBorder,
            width: 2,
          ),
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
    this.itemLabel,
  });

  final T? value;
  final List<T> items;
  final String hint;
  final ValueChanged<T?> onChanged;
  final String Function(T item)? itemLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.fmColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fmColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: AppTextStyles.bodyLarge.copyWith(
              color: context.fmColors.textMuted,
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel?.call(item) ?? item.toString(),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: context.fmColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: context.fmColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ServingSizeSelect extends StatelessWidget {
  const _ServingSizeSelect({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.fmColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fmColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          hint: Text(
            'Optional',
            style: AppTextStyles.bodyLarge.copyWith(
              color: context.fmColors.textMuted,
            ),
          ),
          onChanged: onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: context.fmColors.textMuted,
          ),
          items: <DropdownMenuItem<int>>[
            const DropdownMenuItem<int>(
              value: null,
              child: Text('Not specified'),
            ),
            ...List<int>.generate(10, (index) => index + 1).map(
                (item) => DropdownMenuItem<int>(
                  value: item,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.groups_2_outlined,
                        size: 16,
                        color: context.fmColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$item',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: context.fmColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
    final FoodMatchThemeColors colors = context.fmColors;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 22,
        bottom: bottomInset + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                widget.initialIngredient == null
                    ? 'Add ingredient'
                    : 'Edit ingredient',
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: 19,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: colors.textMuted),
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
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  )
                : (_results.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String result = _results[index];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                result,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  final String ingredientName =
                      (_selectedIngredient ?? _searchController.text).trim();
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
